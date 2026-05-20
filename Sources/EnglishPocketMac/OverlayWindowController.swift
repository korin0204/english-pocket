import AppKit
import Combine
import EnglishPocketCore
import SwiftUI

#if canImport(Translation)
@preconcurrency import Translation
#endif

@MainActor
final class OverlayWindowController {
    private let model: AppModel
    private let logger = AppLogger(category: "Overlay")
    private var panel: NSPanel?
    private var cancellable: AnyCancellable?
    private var mouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var keyMonitor: Any?
    private var localKeyMonitor: Any?
    private var hostingController: NSHostingController<TranslationOverlayContainerView>?

    init(model: AppModel) {
        self.model = model
        cancellable = model.$overlayState.sink { [weak self] state in
            Task { @MainActor in
                self?.render(state)
            }
        }
    }

    private func render(_ state: OverlayState?) {
        guard let state else {
            hide()
            return
        }

        let panel = panel ?? makePanel()
        self.panel = panel

        if hostingController == nil {
            let controller = NSHostingController(rootView: TranslationOverlayContainerView(model: model))
            hostingController = controller
            panel.contentViewController = controller
        }

        panel.setFrameOrigin(origin(for: state, panelSize: panel.frame.size))
        panel.orderFrontRegardless()
        installDismissMonitors()
        logger.write("Showing overlay for \(state.sourceText) using \(state.anchor.strategy)")
    }

    private func hide() {
        if panel?.isVisible == true {
            logger.write("Hiding overlay")
        }
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 128),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        return panel
    }

    private func installDismissMonitors() {
        if mouseMonitor == nil {
            mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
                Task { @MainActor in
                    self?.dismissIfMouseOutside()
                }
            }
        }

        if localMouseMonitor == nil {
            localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
                Task { @MainActor in
                    self?.dismissIfMouseOutside()
                }
                return event
            }
        }

        if keyMonitor == nil {
            keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.keyCode == 53 else { return }
                Task { @MainActor in
                    self?.model.dismissOverlay()
                }
            }
        }

        if localKeyMonitor == nil {
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.keyCode == 53 else { return event }
                Task { @MainActor in
                    self?.model.dismissOverlay()
                }
                return event
            }
        }
    }

    private func dismissIfMouseOutside() {
        guard let panel, panel.isVisible else { return }
        if !panel.frame.contains(NSEvent.mouseLocation) {
            model.dismissOverlay()
        }
    }

    private func origin(for state: OverlayState, panelSize: CGSize) -> CGPoint {
        let anchorRect = normalizedRect(from: state.anchor)
        let screen = screen(containing: anchorRect) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let preferredX = anchorRect.midX - panelSize.width / 2
        let preferredY = anchorRect.maxY + 8
        let fallbackY = anchorRect.minY - panelSize.height - 8
        let x = min(max(preferredX, visibleFrame.minX + 8), visibleFrame.maxX - panelSize.width - 8)
        let y = preferredY + panelSize.height <= visibleFrame.maxY
            ? preferredY
            : max(fallbackY, visibleFrame.minY + 8)
        return CGPoint(x: x, y: y)
    }

    private func normalizedRect(from anchor: CaptureAnchor) -> CGRect {
        let rect = CGRect(x: anchor.x, y: anchor.y, width: max(anchor.width, 1), height: max(anchor.height, 1))
        guard anchor.strategy.hasPrefix("accessibility"), let screen = NSScreen.main else {
            return rect
        }

        return CGRect(
            x: rect.origin.x,
            y: screen.frame.maxY - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    private func screen(containing rect: CGRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.intersects(rect) || $0.frame.contains(rect.origin) }
    }
}

private struct TranslationOverlayContainerView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            if let state = model.overlayState {
                TranslationOverlayView(state: state, model: model)
            }

            OverlaySystemTranslationResolver(model: model)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityHidden(true)
        }
    }
}

private struct TranslationOverlayView: View {
    let state: OverlayState
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.sourceText)
                        .font(.headline)
                        .lineLimit(1)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    model.dismissOverlay()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Dismiss")
            }

            Text(mainText)
                .font(.title3)
                .fontWeight(.semibold)
                .lineLimit(2)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                if isWorking {
                    ProgressView()
                        .controlSize(.small)
                    Button("Cancel") {
                        model.cancelCurrentUITranslation()
                    }
                    .buttonStyle(.borderless)
                }
                Spacer()
                Text("\(state.sourceLanguage.uppercased()) → \(state.targetLanguage.uppercased())")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 320, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary)
        )
    }

    private var mainText: String {
        switch state.status {
        case .failed(let message):
            return message
        case .cancelled:
            return state.translationText ?? "Translation cancelled"
        default:
            return state.translationText ?? "Translating..."
        }
    }

    private var statusText: String {
        if let provider = state.provider, !provider.isEmpty {
            return "\(state.status.label) · \(provider)"
        }
        return state.status.label
    }

    private var isWorking: Bool {
        state.status == .saving || state.status == .translating
    }
}

#if canImport(Translation)
private struct OverlaySystemTranslationResolver: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if let pending = model.pendingUITranslation {
            OverlayTranslationTaskView(
                request: pending,
                model: model
            )
            .id(pending.id)
        } else {
            Color.clear
        }
    }
}

private struct OverlayTranslationTaskView: View {
    let request: UITranslationRequest
    @ObservedObject var model: AppModel
    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear {
                var nextConfiguration = TranslationSession.Configuration(
                    source: Locale.Language(identifier: request.sourceLanguage),
                    target: Locale.Language(identifier: request.targetLanguage)
                )
                nextConfiguration.invalidate()
                configuration = nextConfiguration
            }
            .translationTask(configuration) { session in
                guard model.pendingUITranslation?.id == request.id else {
                    return
                }

                do {
                    let response = try await session.translate(request.text)
                    let result = TranslationResult(
                        sourceText: response.sourceText,
                        targetText: response.targetText,
                        sourceLanguage: response.sourceLanguage.languageCode?.identifier,
                        targetLanguage: response.targetLanguage.languageCode?.identifier ?? request.targetLanguage,
                        provider: "Apple Translation UI"
                    )
                    await MainActor.run {
                        model.applyUITranslation(result, requestID: request.id)
                    }
                } catch {
                await MainActor.run {
                    if error is CancellationError {
                        model.retryUITranslationAfterCancellation(requestID: request.id)
                    } else {
                        model.failUITranslation(error, requestID: request.id)
                    }
                }
            }
    }
    }
}
#else
private struct OverlaySystemTranslationResolver: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Color.clear
    }
}
#endif

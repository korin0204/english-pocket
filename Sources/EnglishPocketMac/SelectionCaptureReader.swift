import AppKit
import ApplicationServices
import Carbon
import EnglishPocketCore

struct SelectionCaptureResult {
    var text: String
    var sourceApp: String
    var method: String
}

@MainActor
final class SelectionCaptureReader {
    private let logger = AppLogger(category: "SelectionCapture")

    func readSelectedText() async -> SelectionCaptureResult? {
        if let accessibilityResult = readAccessibilitySelection() {
            return accessibilityResult
        }

        return await readClipboardFallback()
    }

    func accessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func readAccessibilitySelection() -> SelectionCaptureResult? {
        guard accessibilityTrusted() else {
            logger.write("Accessibility is not trusted; skipping AX selection.")
            return nil
        }

        guard let app = NSWorkspace.shared.frontmostApplication else {
            logger.write("No frontmost application.")
            return nil
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedValue: CFTypeRef?
        let focusedStatus = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard focusedStatus == .success, let focusedValue else {
            logger.write("AX focused element unavailable for \(app.localizedName ?? "unknown"): \(focusedStatus.rawValue)")
            return nil
        }

        let focusedElement = focusedValue as! AXUIElement
        var selectedTextValue: CFTypeRef?
        let selectedStatus = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            &selectedTextValue
        )

        guard selectedStatus == .success, let selectedText = selectedTextValue as? String else {
            logger.write("AX selected text unavailable for \(app.localizedName ?? "unknown"): \(selectedStatus.rawValue)")
            return nil
        }

        let cleaned = TextNormalizer.displayText(selectedText)
        guard !cleaned.isEmpty else {
            logger.write("AX selected text was empty after normalization.")
            return nil
        }

        logger.write("Captured selected text with AX from \(app.localizedName ?? "unknown"): \(cleaned)")
        return SelectionCaptureResult(
            text: cleaned,
            sourceApp: app.localizedName ?? "",
            method: "Accessibility"
        )
    }

    @MainActor
    private func readClipboardFallback() async -> SelectionCaptureResult? {
        let pasteboard = NSPasteboard.general
        let originalItems = pasteboard.pasteboardItems ?? []
        let originalChangeCount = pasteboard.changeCount
        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""

        sendCopyCommand()

        let copiedText = await waitForPasteboardText(after: originalChangeCount)
        restorePasteboard(items: originalItems)

        guard let copiedText else {
            logger.write("Clipboard fallback failed for \(sourceApp).")
            return nil
        }

        logger.write("Captured selected text with clipboard fallback from \(sourceApp): \(copiedText)")
        return SelectionCaptureResult(
            text: copiedText,
            sourceApp: sourceApp,
            method: "Clipboard fallback"
        )
    }

    @MainActor
    private func waitForPasteboardText(after changeCount: Int) async -> String? {
        let pasteboard = NSPasteboard.general

        for _ in 0..<10 {
            try? await Task.sleep(for: .milliseconds(35))
            guard pasteboard.changeCount != changeCount else {
                continue
            }

            if let text = pasteboard.string(forType: .string) {
                let cleaned = TextNormalizer.displayText(text)
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }

        return nil
    }

    private func sendCopyCommand() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        keyDown?.flags = CGEventFlags.maskCommand
        keyUp?.flags = CGEventFlags.maskCommand
        keyDown?.post(tap: CGEventTapLocation.cghidEventTap)
        keyUp?.post(tap: CGEventTapLocation.cghidEventTap)
    }

    private func restorePasteboard(items: [NSPasteboardItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
    }
}

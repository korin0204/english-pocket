import AppKit
import EnglishPocketCore

@MainActor
final class ServiceProvider: NSObject {
    private let model: AppModel
    private let showCaptureUI: () -> Void
    private let logger = AppLogger(category: "Services")

    init(model: AppModel, showCaptureUI: @escaping () -> Void) {
        self.model = model
        self.showCaptureUI = showCaptureUI
    }

    @objc(saveText:userData:error:)
    func saveText(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let text = pasteboard.string(forType: .string)
            ?? pasteboard.string(forType: NSPasteboard.PasteboardType("public.utf8-plain-text"))
            ?? pasteboard.string(forType: NSPasteboard.PasteboardType("NSStringPboardType"))

        logger.write("Service invoked. Types: \(pasteboard.types?.map(\.rawValue).joined(separator: ", ") ?? "none")")

        guard let text, !TextNormalizer.displayText(text).isEmpty else {
            logger.write("Service failed: selected text was empty or unreadable.")
            error.pointee = "English Pocket could not read selected text."
            return
        }

        Task { @MainActor in
            logger.write("Capturing selected text: \(TextNormalizer.displayText(text))")
            await model.capture(
                CaptureRequest(
                    text: text,
                    sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName ?? "",
                    action: .saveAndTranslate
                )
            )
            showCaptureUI()
        }
    }
}

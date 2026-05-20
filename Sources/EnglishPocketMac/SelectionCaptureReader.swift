import AppKit
import ApplicationServices
import Carbon
import EnglishPocketCore

struct SelectionCaptureResult {
    var text: String
    var sourceApp: String
    var method: String
    var anchor: CaptureAnchor?
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

    func currentSelectionAnchor() -> CaptureAnchor? {
        guard accessibilityTrusted() else {
            logger.write("Accessibility is not trusted; cannot resolve selection anchor.")
            return nil
        }

        guard let focusedElement = focusedElement() else {
            return nil
        }

        if let anchor = selectedTextAnchor(from: focusedElement) {
            logger.write("Resolved current selection anchor with Accessibility.")
            return anchor
        }

        if let anchor = focusedElementAnchor(from: focusedElement) {
            logger.write("Resolved focused element anchor with Accessibility fallback.")
            return anchor
        }

        logger.write("Accessibility anchor unavailable; falling back to mouse.")
        return nil
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

        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown"
        guard let focusedElement = focusedElement() else { return nil }
        let anchor = selectedTextAnchor(from: focusedElement) ?? focusedElementAnchor(from: focusedElement)
        var selectedTextValue: CFTypeRef?
        let selectedStatus = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            &selectedTextValue
        )

        guard selectedStatus == .success, let selectedText = selectedTextValue as? String else {
            logger.write("AX selected text unavailable for \(sourceApp): \(selectedStatus.rawValue)")
            return nil
        }

        let cleaned = TextNormalizer.displayText(selectedText)
        guard !cleaned.isEmpty else {
            logger.write("AX selected text was empty after normalization.")
            return nil
        }

        logger.write("Captured selected text with AX from \(sourceApp): \(cleaned)")
        return SelectionCaptureResult(
            text: cleaned,
            sourceApp: sourceApp,
            method: "Accessibility",
            anchor: anchor
        )
    }

    private func focusedElement() -> AXUIElement? {
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

        guard CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            logger.write("AX focused value was not an element for \(app.localizedName ?? "unknown").")
            return nil
        }

        return (focusedValue as! AXUIElement)
    }

    private func selectedTextAnchor(from element: AXUIElement) -> CaptureAnchor? {
        var rangeValue: CFTypeRef?
        let rangeStatus = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        )

        guard rangeStatus == .success, let rangeValue else {
            return nil
        }

        var boundsValue: CFTypeRef?
        let boundsStatus = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsValue
        )

        guard boundsStatus == .success, let boundsValue else {
            return nil
        }

        return anchor(from: boundsValue, strategy: "accessibility-selection")
    }

    private func focusedElementAnchor(from element: AXUIElement) -> CaptureAnchor? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        let positionStatus = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue)
        let sizeStatus = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)

        guard
            positionStatus == .success,
            sizeStatus == .success,
            let positionValue,
            let sizeValue
        else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard
            CFGetTypeID(positionValue) == AXValueGetTypeID(),
            CFGetTypeID(sizeValue) == AXValueGetTypeID(),
            AXValueGetType(positionValue as! AXValue) == .cgPoint,
            AXValueGetType(sizeValue as! AXValue) == .cgSize,
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &point),
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        else {
            return nil
        }

        guard size.width > 0, size.height > 0 else {
            return nil
        }

        return CaptureAnchor(
            x: point.x,
            y: point.y,
            width: size.width,
            height: size.height,
            strategy: "accessibility-focused-element"
        )
    }

    private func anchor(from value: CFTypeRef, strategy: String) -> CaptureAnchor? {
        guard
            CFGetTypeID(value) == AXValueGetTypeID(),
            AXValueGetType(value as! AXValue) == .cgRect
        else {
            return nil
        }

        let axValue = value as! AXValue
        var rect = CGRect.zero
        guard AXValueGetValue(axValue, .cgRect, &rect), rect.width > 0, rect.height > 0 else {
            return nil
        }

        return CaptureAnchor(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.width,
            height: rect.height,
            strategy: strategy
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
            method: "Clipboard fallback",
            anchor: mouseAnchor(strategy: "clipboard-mouse")
        )
    }

    private func mouseAnchor(strategy: String) -> CaptureAnchor {
        let point = NSEvent.mouseLocation
        return CaptureAnchor(x: point.x, y: point.y, width: 1, height: 1, strategy: strategy)
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

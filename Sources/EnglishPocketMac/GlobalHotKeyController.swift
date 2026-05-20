import AppKit
import Carbon
import Foundation

final class GlobalHotKeyController {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private let action: @MainActor () -> Void
    private let logger = AppLogger(category: "HotKey")

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    deinit {
        unregister()
    }

    func register() {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr, hotKeyID.id == 1 else {
                    return noErr
                }

                let controller = Unmanaged<GlobalHotKeyController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                controller.handleHotKey()
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )

        guard installStatus == noErr else {
            logger.write("Failed to install hotkey handler: \(installStatus)")
            return
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature("ENPK"), id: 1)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_C),
            UInt32(controlKey | optionKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(0),
            &hotKeyRef
        )

        if registerStatus == noErr {
            logger.write("Registered Ctrl+Option+Shift+C global hotkey.")
        } else {
            logger.write("Failed to register Ctrl+Option+Shift+C global hotkey: \(registerStatus). Event monitor fallback is disabled by default.")
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }

        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }

        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
    }

    private func handleHotKey() {
        DispatchQueue.main.async { [action] in
            MainActor.assumeIsolated {
                action()
            }
        }
    }

    private func installEventMonitorFallback() {
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleIfCaptureShortcut(event)
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleIfCaptureShortcut(event)
            return event
        }
        logger.write("Installed Ctrl+Option+C event monitor fallback.")
    }

    private func handleIfCaptureShortcut(_ event: NSEvent) {
        guard !event.isARepeat else { return }
        guard event.keyCode == UInt16(kVK_ANSI_C) else { return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.control), flags.contains(.option), flags.contains(.shift), !flags.contains(.command) else {
            return
        }
        handleHotKey()
    }

    private static func signature(_ value: String) -> OSType {
        value.utf8.reduce(0) { partial, byte in
            (partial << 8) + OSType(byte)
        }
    }
}

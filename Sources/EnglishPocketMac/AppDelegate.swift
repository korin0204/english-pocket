import AppKit
import EnglishPocketCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let appModel = AppModel()
    private var serviceProvider: ServiceProvider!
    private var hotKeyController: GlobalHotKeyController!
    private let selectionReader = SelectionCaptureReader()

    func applicationWillFinishLaunching(_ notification: Notification) {
        enforceSingleInstance()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureApplicationMenu()
        configureStatusItem()
        configurePopover()
        configureServices()
        configureGlobalCaptureIfNeeded()
        appModel.load()
    }

    private func configureApplicationMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit English Pocket",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func enforceSingleInstance() {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.mizunoshoma.EnglishPocket"
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let otherRunningApp = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first { $0.processIdentifier != currentPID }

        if let otherRunningApp {
            otherRunningApp.activate()
            NSApp.terminate(nil)
        }
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "text.badge.plus", accessibilityDescription: "English Pocket")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 440, height: 560)
        popover.contentViewController = NSHostingController(rootView: RootView(model: appModel))
    }

    private func configureServices() {
        serviceProvider = ServiceProvider(model: appModel) { [weak self] in
            self?.showPopover()
        }
        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()
    }

    private func configureGlobalCaptureIfNeeded() {
        guard appModel.globalCaptureEnabled else { return }
        hotKeyController = GlobalHotKeyController { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.captureFromGlobalHotKey()
            }
        }
        hotKeyController.register()
    }

    private func captureFromGlobalHotKey() async {
        guard let result = await selectionReader.readSelectedText() else {
            appModel.statusMessage = selectionReader.accessibilityTrusted()
                ? "No selected text found"
                : "Allow Accessibility access or use the Services shortcut"
            showPopover()
            return
        }

        await appModel.capture(
            CaptureRequest(
                text: result.text,
                sourceApp: result.sourceApp,
                sourceTitle: result.method,
                action: .saveAndTranslate
            )
        )
        showPopover()
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }
}

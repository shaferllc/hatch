import AppKit
import SwiftUI

@main
struct HatchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = Store()

    private var statusItem: NSStatusItem?
    private var panelController: PanelController?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = PanelController(store: store)
        controller.openSettingsRequested = { [weak self] in self?.openSettings() }
        panelController = controller

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "rectangle.split.3x1",
                                   accessibilityDescription: "Hatch")
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item

        HotKey.shared.onTrigger = { [weak self] in self?.panelController?.toggle() }
        HotKey.shared.register()
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            panelController?.toggle()
        }
    }

    private func showMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open Hatch", action: #selector(openPanel), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let hint = NSMenuItem(title: "Hotkey: \(HotKey.displayString)", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsAction),
                                      keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Hatch", action: #selector(NSApplication.terminate(_:)),
                                  keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        DispatchQueue.main.async { [weak self] in
            self?.statusItem?.menu = nil
        }
    }

    @objc private func openPanel() {
        panelController?.show()
    }

    @objc private func openSettingsAction() {
        openSettings()
    }

    func openSettings() {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView(store: store))
            let window = NSWindow(contentViewController: host)
            window.title = "Hatch Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

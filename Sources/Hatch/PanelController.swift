import AppKit
import Carbon.HIToolbox
import QuickLookUI
import SwiftUI

/// Owns the panel, the browser model, and all keyboard routing.
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    let panel: HatchPanel
    let model: BrowserModel

    var openSettingsRequested: (() -> Void)?

    private var keyMonitor: Any?

    init(store: Store) {
        panel = HatchPanel()
        model = BrowserModel(store: store)
        super.init()

        panel.delegate = self
        let host = NSHostingView(rootView: PanelRootView(model: model, store: store))
        host.frame = NSRect(x: 0, y: 0, width: 760, height: 480)
        panel.contentView = host

        model.dismiss = { [weak self] in self?.hide() }
        model.onSelectionChanged = { [weak self] in self?.selectionChanged() }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKey(event)
        }
    }

    // MARK: Show / hide

    func toggle() {
        if panel.isVisible { hide() } else { show() }
    }

    func show() {
        guard let screen = screenWithMouse() else { return }
        let vf = screen.visibleFrame
        let size = NSSize(width: 760, height: 480)
        let origin = NSPoint(x: vf.midX - size.width / 2,
                             y: vf.maxY - size.height - vf.height * 0.12)
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
        model.reset()
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        closeQuickLookIfOpen()
        panel.orderOut(nil)
    }

    private func screenWithMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) }
            ?? NSScreen.main ?? NSScreen.screens.first
    }

    // MARK: NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        // Losing key to our own Quick Look panel shouldn't dismiss Hatch.
        if QLPreviewPanel.sharedPreviewPanelExists(),
           QLPreviewPanel.shared().isKeyWindow { return }
        hide()
    }

    // MARK: Quick Look

    private func selectionChanged() {
        guard QLPreviewPanel.sharedPreviewPanelExists(),
              let ql = QLPreviewPanel.shared(), ql.isVisible else { return }
        panel.previewSource.url = model.selectedItem?.url
        ql.reloadData()
    }

    private func toggleQuickLook() {
        guard let ql = QLPreviewPanel.shared() else { return }
        panel.previewSource.url = model.selectedItem?.url
        if ql.isVisible {
            ql.orderOut(nil)
        } else {
            ql.makeKeyAndOrderFront(nil)
        }
    }

    private func closeQuickLookIfOpen() {
        guard QLPreviewPanel.sharedPreviewPanelExists(),
              let ql = QLPreviewPanel.shared(), ql.isVisible else { return }
        ql.orderOut(nil)
    }

    // MARK: Keyboard

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        guard panel.isKeyWindow else { return event }
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let cmd = mods.contains(.command)

        switch Int(event.keyCode) {
        case kVK_Escape:
            if model.activeFilter.isEmpty { hide() } else { model.clearFilter() }
            return nil
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if cmd { model.revealSelection() } else { model.openSelection() }
            return nil
        case kVK_Space:
            toggleQuickLook()
            return nil
        case kVK_LeftArrow:
            model.back()
            return nil
        case kVK_RightArrow:
            model.descend()
            return nil
        case kVK_DownArrow:
            model.move(1)
            return nil
        case kVK_UpArrow:
            model.move(-1)
            return nil
        case kVK_Delete:
            model.backspaceFilter()
            return nil
        case kVK_Tab:
            return nil
        default:
            break
        }

        if cmd {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "c": model.copySelection(); return nil
            case "d": model.toggleFavoriteSelection(); return nil
            case ".": model.toggleHidden(); return nil
            case ",": hide(); openSettingsRequested?(); return nil
            case "q": NSApp.terminate(nil); return nil
            default: return event
            }
        }

        // Printable characters feed the type-to-filter for the active column.
        if !mods.contains(.control),
           let chars = event.characters, !chars.isEmpty,
           let scalar = chars.unicodeScalars.first,
           !CharacterSet.controlCharacters.contains(scalar) {
            model.appendFilter(chars)
            return nil
        }
        return event
    }
}

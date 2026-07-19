import AppKit
import QuickLookUI

/// Serves the current selection to QLPreviewPanel. Kept nonisolated because
/// QuickLook's informal protocols are nonisolated; the url is only mutated on
/// the main thread.
final class PreviewDataSource: NSObject, QLPreviewPanelDataSource {
    nonisolated(unsafe) var url: URL?

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        url == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        url as NSURL?
    }
}

/// Borderless, non-activating Spotlight-style panel.
final class HatchPanel: NSPanel {
    let previewSource = PreviewDataSource()

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 760, height: 480),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // MARK: Quick Look responder-chain control

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        true
    }

    // These informal-protocol overrides are nonisolated in the SDK but are
    // only ever invoked on the main thread by AppKit.
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            panel.dataSource = self.previewSource
        }
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            if panel.dataSource === self.previewSource {
                panel.dataSource = nil
            }
        }
    }
}

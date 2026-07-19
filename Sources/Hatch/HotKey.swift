import AppKit
import Carbon.HIToolbox

/// System-wide hotkey via Carbon — no Accessibility permission needed.
/// Hatch registers exactly one combo: ⌥⌘F.
@MainActor
final class HotKey {
    static let shared = HotKey()

    static let displayString = "⌥⌘F"

    /// Invoked on the main thread when the hotkey fires.
    var onTrigger: (() -> Void)?

    private var ref: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private init() {}

    func register() {
        installHandlerIfNeeded()
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        let hotKeyID = EventHotKeyID(signature: OSType(0x48544348), // 'HTCH'
                                     id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_F),
                            UInt32(optionKey | cmdKey),
                            hotKeyID, GetApplicationEventTarget(), 0, &ref)
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated {
                hotKey.onTrigger?()
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }
}

import AppKit
import Carbon.HIToolbox

/// A single global hotkey via Carbon's RegisterEventHotKey — works without the
/// Accessibility/Input-Monitoring permission that NSEvent global monitors need.
/// We only ever need one, so this is a lightweight singleton.
final class HotKey {
    // Carbon delivers hotkey events on the main run-loop thread, so this is safe.
    nonisolated(unsafe) static let shared = HotKey()

    private var ref: EventHotKeyRef?
    private var onPress: (() -> Void)?

    private init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            HotKey.shared.onPress?()
            return noErr
        }, 1, &spec, nil, nil)
    }

    /// Default binding is ⌥Space (Option+Space). Spotlight owns ⌘Space, so we stay clear.
    func register(keyCode: UInt32 = UInt32(kVK_Space),
                  modifiers: UInt32 = UInt32(optionKey),
                  onPress: @escaping () -> Void) {
        self.onPress = onPress
        if let ref { UnregisterEventHotKey(ref); self.ref = nil }
        let hotID = EventHotKeyID(signature: OSType(0x4445434B), id: 1) // 'DECK'
        RegisterEventHotKey(keyCode, modifiers, hotID, GetApplicationEventTarget(), 0, &ref)
    }
}
import AppKit

/// Audible cue when a console changes to a state where it's your move. This is the
/// reliable channel — native notification sounds are easy to miss or mute, which is
/// exactly what the user hit. Played in addition to (not instead of) the banner.
enum Sound {
    static func play(for status: AgentStatus) {
        let name: String?
        switch status {
        case .finished: name = "Glass"   // turn done — you can type the next command
        case .waiting:  name = "Tink"     // needs permission/input now
        case .error:    name = "Basso"
        default:        name = nil
        }
        if let name { NSSound(named: name)?.play() }
    }
}

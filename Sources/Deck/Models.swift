import Foundation

/// One line as written by deck-hook.py.
struct DeckEvent: Codable {
    var ts: String = ""
    var event: String = ""
    var agent_id: String = ""
    var session_id: String = ""
    var cwd: String = ""
    var transcript_path: String = ""
    var tool: String = ""
    var detail: String = ""
}

/// A folder the user saved for one-click console launches.
struct Project: Codable, Identifiable {
    var id: String
    var name: String
    var path: String
}

/// Persisted record of an agent Deck launched itself.
struct AgentRegistration: Codable, Identifiable {
    var id: String            // DECK_AGENT_ID (uuid)
    var name: String
    var cwd: String
    var itermSessionId: String
    var created: Date
}

enum AgentStatus: String {
    case starting      // SessionStart — ready, awaiting your first prompt
    case working       // mid-turn, running tools
    case finished      // Stop — turn done, your move
    case waiting       // Notification — needs permission / input now
    case error         // StopFailure
    case closed        // SessionEnd

    var label: String {
        switch self {
        case .starting: return "готов"
        case .working: return "работает"
        case .finished: return "закончил"
        case .waiting: return "ждёт тебя"
        case .error: return "ошибка"
        case .closed: return "закрыт"
        }
    }

    /// States that should ping you and draw the eye.
    var needsYou: Bool { self == .finished || self == .waiting || self == .error }
}

/// A live agent as shown in the UI: registry + reduced events.
struct Agent: Identifiable {
    var id: String             // agent_id, or "session:<id>" for externally-started ones
    var name: String
    var cwd: String
    var itermSessionId: String // empty if we can't focus it
    var claudeSessionId: String
    var status: AgentStatus
    var activity: String       // "Edit foo.ts" etc.
    var lastChange: Date
    var seen: Bool             // whether you've already looked since it last needed you

    var projectName: String {
        let base = (cwd as NSString).lastPathComponent
        return base.isEmpty ? "—" : base
    }

    var canFocus: Bool { !itermSessionId.isEmpty }
}

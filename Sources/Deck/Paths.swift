import Foundation

enum Paths {
    static let home = FileManager.default.homeDirectoryForCurrentUser

    static var deckDir: URL { home.appendingPathComponent(".deck", isDirectory: true) }
    static var eventsFile: URL { deckDir.appendingPathComponent("events.jsonl") }
    static var agentsFile: URL { deckDir.appendingPathComponent("agents.json") }
    static var projectsFile: URL { deckDir.appendingPathComponent("projects.json") }
    static var hookScript: URL { deckDir.appendingPathComponent("deck-hook.py") }

    static var claudeSettings: URL {
        home.appendingPathComponent(".claude/settings.json")
    }

    static func ensureDeckDir() {
        try? FileManager.default.createDirectory(at: deckDir, withIntermediateDirectories: true)
    }
}

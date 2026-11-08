import Foundation
import Observation

/// Projects the user saved so they can spin up a console with one click instead of
/// re-picking a folder every time. Persisted to ~/.deck/projects.json.
@MainActor
@Observable
final class ProjectStore {
    private(set) var projects: [Project] = []

    init() {
        Paths.ensureDeckDir()
        load()
    }

    /// Adds (or updates the name of) a project, keyed by path so folders don't duplicate.
    @discardableResult
    func add(name: String, path: String) -> Project {
        if let i = projects.firstIndex(where: { $0.path == path }) {
            projects[i].name = name
            save()
            return projects[i]
        }
        let p = Project(id: UUID().uuidString, name: name, path: path)
        projects.append(p)
        save()
        return p
    }

    func remove(_ id: String) {
        projects.removeAll { $0.id == id }
        save()
    }

    func rename(_ id: String, to name: String) {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[i].name = name
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: Paths.projectsFile),
              let list = try? JSONDecoder.deck.decode([Project].self, from: data)
        else { return }
        projects = list
    }

    private func save() {
        if let data = try? JSONEncoder.deck.encode(projects) {
            try? data.write(to: Paths.projectsFile)
        }
    }
}

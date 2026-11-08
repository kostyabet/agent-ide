import Foundation
import Observation

@MainActor
@Observable
final class EventStore {
    private(set) var agents: [Agent] = []

    private var registry: [String: AgentRegistration] = [:]   // agent_id -> registration
    private var reduced: [String: ReducedAgent] = [:]         // key -> reduced
    private var unseen: Set<String> = []                      // keys that need you and weren't looked at
    private var offset: UInt64 = 0
    private var pending = ""                                  // partial trailing line
    private var timer: Timer?

    var notifier: ((Agent) -> Void)?

    private let isoParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    struct ReducedAgent {
        var claudeSessionId = ""
        var cwd = ""
        var status: AgentStatus = .starting
        var activity = ""
        var lastChange = Date()
    }

    init() {
        Paths.ensureDeckDir()
        loadRegistry()
        catchUp()               // apply existing history without notifying
        rebuild()
    }

    func start() {
        let t = Timer(timeInterval: 0.7, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: registry

    private func loadRegistry() {
        guard let data = try? Data(contentsOf: Paths.agentsFile),
              let list = try? JSONDecoder.deck.decode([AgentRegistration].self, from: data)
        else { return }
        for r in list { registry[r.id] = r }
    }

    private func saveRegistry() {
        let list = Array(registry.values)
        if let data = try? JSONEncoder.deck.encode(list) {
            try? data.write(to: Paths.agentsFile)
        }
    }

    func register(_ reg: AgentRegistration) {
        registry[reg.id] = reg
        // seed a reduced entry so it shows immediately as "готов"
        if reduced[reg.id] == nil {
            reduced[reg.id] = ReducedAgent(cwd: reg.cwd, status: .starting, lastChange: Date())
        }
        saveRegistry()
        rebuild()
    }

    func removeAgent(_ id: String) {
        registry[id] = nil
        reduced[id] = nil
        unseen.remove(id)
        saveRegistry()
        rebuild()
    }

    func rename(_ id: String, to name: String) {
        guard var reg = registry[id] else { return }
        reg.name = name
        registry[id] = reg
        saveRegistry()
        rebuild()
    }

    func markSeen(_ id: String) {
        if unseen.remove(id) != nil { rebuild() }
    }

    // MARK: reading events

    /// Apply everything already in the file, set offset to end, do not notify.
    private func catchUp() {
        guard let data = try? Data(contentsOf: Paths.eventsFile) else { return }
        offset = UInt64(data.count)
        guard let text = String(data: data, encoding: .utf8) else { return }
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            apply(line: String(line), notify: false)
        }
    }

    private func poll() {
        guard let handle = try? FileHandle(forReadingFrom: Paths.eventsFile) else { return }
        defer { try? handle.close() }

        let size = (try? handle.seekToEnd()) ?? 0
        if size < offset {                 // file was truncated/replaced — reset
            offset = 0
            reduced.removeAll()
            unseen.removeAll()
            pending = ""
        }
        if size == offset { return }

        try? handle.seek(toOffset: offset)
        let data = (try? handle.readToEnd()) ?? Data()
        offset = size
        guard var text = String(data: data, encoding: .utf8) else { return }

        text = pending + text
        pending = ""
        if !text.hasSuffix("\n") {
            // stash the incomplete trailing line for next poll
            if let lastNL = text.lastIndex(of: "\n") {
                pending = String(text[text.index(after: lastNL)...])
                text = String(text[...lastNL])
            } else {
                pending = text
                text = ""
            }
        }

        var changed = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            apply(line: String(line), notify: true)
            changed = true
        }
        if changed { rebuild() }
    }

    private func apply(line: String, notify: Bool) {
        guard let data = line.data(using: .utf8),
              let ev = try? JSONDecoder.deck.decode(DeckEvent.self, from: data)
        else { return }

        let key = ev.agent_id.isEmpty ? "session:\(ev.session_id)" : ev.agent_id
        if key == "session:" { return }

        var r = reduced[key] ?? ReducedAgent()
        let old = r.status
        if !ev.session_id.isEmpty { r.claudeSessionId = ev.session_id }
        if !ev.cwd.isEmpty { r.cwd = ev.cwd }
        if let t = isoParser.date(from: ev.ts) { r.lastChange = t } else { r.lastChange = Date() }

        switch ev.event {
        case "SessionStart": r.status = .starting
        case "UserPromptSubmit": r.status = .working; r.activity = "думает…"
        case "PreToolUse": r.status = .working; r.activity = activityLabel(ev)
        case "PostToolUse": r.status = .working
        case "Notification": r.status = .waiting
        case "Stop": r.status = .finished; r.activity = ""
        case "StopFailure": r.status = .error
        case "SessionEnd": r.status = .closed
        default: break
        }

        reduced[key] = r

        if r.status.needsYou && old != r.status {
            unseen.insert(key)
            if notify {
                pendingNotify.append(key)
                Sound.play(for: r.status)   // audible cue — don't rely on the banner
            }
        }
    }

    private func activityLabel(_ ev: DeckEvent) -> String {
        ev.detail.isEmpty ? ev.tool : "\(ev.tool) \(ev.detail)"
    }

    // MARK: building the view model

    private var pendingNotify: [String] = []

    private func rebuild() {
        var out: [Agent] = []
        for (key, r) in reduced {
            let reg = registry[key]
            let name = reg?.name ?? defaultName(key: key, r: r)
            out.append(Agent(
                id: key,
                name: name,
                cwd: reg?.cwd.isEmpty == false ? reg!.cwd : r.cwd,
                itermSessionId: reg?.itermSessionId ?? "",
                claudeSessionId: r.claudeSessionId,
                status: r.status,
                activity: r.activity,
                lastChange: r.lastChange,
                seen: !unseen.contains(key)
            ))
        }
        agents = out.sorted(by: Self.order)

        // fire queued notifications for the freshly-rebuilt agents
        if let notifier {
            let byKey = Dictionary(uniqueKeysWithValues: out.map { ($0.id, $0) })
            for key in pendingNotify { if let a = byKey[key] { notifier(a) } }
        }
        pendingNotify.removeAll()
    }

    private func defaultName(key: String, r: ReducedAgent) -> String {
        if key.hasPrefix("session:") {
            let base = (r.cwd as NSString).lastPathComponent
            return base.isEmpty ? "external" : base
        }
        return "agent"
    }

    private static func order(_ a: Agent, _ b: Agent) -> Bool {
        func rank(_ s: AgentStatus) -> Int {
            switch s {
            case .waiting: return 0
            case .error: return 1
            case .finished: return 2
            case .working: return 3
            case .starting: return 4
            case .closed: return 5
            }
        }
        if rank(a.status) != rank(b.status) { return rank(a.status) < rank(b.status) }
        return a.lastChange > b.lastChange
    }

    // Aggregate for the menu-bar icon.
    var hasUnseenNeedsYou: Bool {
        agents.contains { $0.status.needsYou && !$0.seen }
    }
    var anyWorking: Bool {
        agents.contains { $0.status == .working }
    }
}

extension JSONDecoder {
    static var deck: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
extension JSONEncoder {
    static var deck: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted]
        return e
    }
}

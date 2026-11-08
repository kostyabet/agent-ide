import SwiftUI
import AppKit

struct PanelView: View {
    let store: EventStore
    let projects: ProjectStore
    var onClose: () -> Void

    @State private var hooksInstalled = HookInstaller.isInstalled
    @State private var installError: String?

    private var groups: [(project: String, agents: [Agent])] {
        var order: [String] = []
        var map: [String: [Agent]] = [:]
        for a in store.agents where a.status != .closed {
            if map[a.projectName] == nil { order.append(a.projectName) }
            map[a.projectName, default: []].append(a)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !hooksInstalled { installBanner }

            consoles

            Divider().opacity(0.5)

            quickLaunch
        }
        .padding(16)
        .frame(width: 360)
        .frame(maxHeight: 520, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: header

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.tint)
            Text("Deck").font(.system(size: 16, weight: .bold))
            Spacer()
            Text("⌥Space")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
            Menu {
                Button("Выход") { NSApplication.shared.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private var installBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Хуки Claude Code не установлены").font(.callout).bold()
            Text("Добавит статус-хук рядом с твоими (cc-status/pandev их не тронет). Создаст бэкап settings.json.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let installError {
                Text(installError).font(.caption).foregroundStyle(.red)
            }
            Button("Установить хуки") {
                installError = HookInstaller.install()
                hooksInstalled = HookInstaller.isInstalled
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: consoles

    private var consoles: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Консоли")
            if groups.isEmpty {
                Text("Пока пусто. Запусти консоль из проекта ниже.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(groups, id: \.project) { group in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(group.project.uppercased())
                                    .font(.caption2).bold().foregroundStyle(.tertiary)
                                ForEach(group.agents) { agent in
                                    AgentRow(agent: agent, store: store)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
    }

    // MARK: quick launch

    private var quickLaunch: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel("Запустить консоль")
                Spacer()
                Menu {
                    Button("Добавить проект…") { addProject() }
                    Button("Запустить из папки…") { launchFromFolder() }
                } label: {
                    Image(systemName: "plus")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }

            if projects.projects.isEmpty {
                Text("Добавь проект, чтобы запускать консоль в один клик.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                FlowLayout(spacing: 7) {
                    ForEach(projects.projects) { project in
                        ProjectChip(project: project,
                                    launch: { launchFromProject(project) },
                                    rename: { renameProject(project) },
                                    remove: { projects.remove(project.id) })
                    }
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2).bold().foregroundStyle(.secondary)
    }

    // MARK: actions

    private func launch(cwd: String, name: String) {
        let id = UUID().uuidString
        guard let sessionId = ITermController.launch(agentId: id, cwd: cwd, name: name) else {
            Dialogs.error("Не удалось запустить iTerm. Разреши управление iTerm в «Системные настройки → Конфиденциальность → Автоматизация».")
            return
        }
        store.register(AgentRegistration(
            id: id, name: name, cwd: cwd, itermSessionId: sessionId, created: Date()))
        onClose()
    }

    private func launchFromProject(_ project: Project) {
        let name = Dialogs.prompt(title: "Имя консоли",
                                  message: "Как назвать эту консоль в \(project.name)?",
                                  defaultValue: project.name) ?? project.name
        launch(cwd: project.path, name: name)
    }

    private func launchFromFolder() {
        guard let folder = Dialogs.pickFolder() else { return }
        let name = Dialogs.prompt(title: "Имя консоли",
                                  message: "Как назвать эту консоль?",
                                  defaultValue: folder.lastPathComponent) ?? folder.lastPathComponent
        launch(cwd: folder.path, name: name)
    }

    private func addProject() {
        guard let folder = Dialogs.pickFolder() else { return }
        let name = Dialogs.prompt(title: "Название проекта",
                                  message: "Как назвать этот проект в списке?",
                                  defaultValue: folder.lastPathComponent) ?? folder.lastPathComponent
        projects.add(name: name, path: folder.path)
    }

    private func renameProject(_ project: Project) {
        if let name = Dialogs.prompt(title: "Переименовать проект",
                                     message: "Новое название",
                                     defaultValue: project.name) {
            projects.rename(project.id, to: name)
        }
    }
}

// MARK: - Project chip

struct ProjectChip: View {
    let project: Project
    var launch: () -> Void
    var rename: () -> Void
    var remove: () -> Void

    var body: some View {
        Button(action: launch) {
            HStack(spacing: 5) {
                Image(systemName: "folder.fill").font(.system(size: 10))
                Text(project.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.quaternary, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(project.path)
        .contextMenu {
            Button("Новая консоль здесь", action: launch)
            Button("Переименовать", action: rename)
            Divider()
            Button("Убрать проект", role: .destructive, action: remove)
        }
    }
}

// MARK: - Agent row

struct AgentRow: View {
    let agent: Agent
    let store: EventStore

    var body: some View {
        Button {
            if agent.canFocus { _ = ITermController.focus(sessionId: agent.itermSessionId) }
            store.markSeen(agent.id)
        } label: {
            HStack(spacing: 9) {
                Circle().fill(color).frame(width: 9, height: 9)
                    .shadow(color: color.opacity(0.6), radius: agent.status == .working ? 3 : 0)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(agent.name).fontWeight(.medium)
                        if agent.status.needsYou && !agent.seen {
                            Circle().fill(Color.red).frame(width: 6, height: 6)
                        }
                    }
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Text(timeAgo).font(.caption2).foregroundStyle(.tertiary)
                Menu {
                    Button("Переименовать") { rename() }
                    Button("Убрать из списка") { store.removeAgent(agent.id) }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 22)
                .fixedSize()
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        agent.activity.isEmpty ? agent.status.label : "\(agent.status.label) · \(agent.activity)"
    }

    private var color: Color {
        switch agent.status {
        case .working: return .blue
        case .finished: return .green
        case .waiting: return .orange
        case .error: return .red
        case .starting, .closed: return .gray
        }
    }

    private var timeAgo: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: agent.lastChange, relativeTo: Date())
    }

    private func rename() {
        if let name = Dialogs.prompt(title: "Переименовать",
                                     message: "Новое имя консоли",
                                     defaultValue: agent.name) {
            store.rename(agent.id, to: name)
        }
    }
}

// MARK: - A simple wrapping layout for the project chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var x: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                totalHeight += rowHeight + spacing
                x = 0; rowHeight = 0
            }
            rows[rows.count - 1].append(view)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Dialogs

@MainActor
enum Dialogs {
    static func pickFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Выбрать проект"
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func prompt(title: String, message: String, defaultValue: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Отмена")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = defaultValue
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }

    static func error(_ text: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Deck"
        alert.informativeText = text
        alert.runModal()
    }
}

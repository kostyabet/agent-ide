import SwiftUI
import AppKit

@main
struct DeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // Accessory app: no windows of its own. All UI is the floating panel + status item.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = EventStore()
    let projects = ProjectStore()
    private var panel: PanelController!
    private var statusItem: StatusItemController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        Notifier.requestAuth()
        store.notifier = { Notifier.notify($0) }
        store.start()

        panel = PanelController(store: store, projects: projects)
        statusItem = StatusItemController(store: store) { [weak self] in
            self?.panel.toggle()
        }
        HotKey.shared.register { [weak self] in
            self?.panel.toggle()
        }
    }
}

extension EventStore {
    var menuIcon: String {
        if hasUnseenNeedsYou { return "bell.badge.fill" }
        if anyWorking { return "circle.hexagongrid.fill" }
        return "rectangle.stack.fill"
    }
}

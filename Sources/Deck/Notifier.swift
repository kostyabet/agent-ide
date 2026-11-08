import Foundation
import UserNotifications

/// Native notifications. No-ops when run outside an app bundle (e.g. `swift run`),
/// where UNUserNotificationCenter has no bundle identifier to attach to.
enum Notifier {
    private static var available: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestAuth() {
        guard available else { return }
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notify(_ agent: Agent) {
        guard available else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(agent.name) — \(agent.status.label)"
        var body = agent.projectName
        if !agent.activity.isEmpty { body += " · \(agent.activity)" }
        content.body = body
        // Sound is handled explicitly by Sound.play so it fires even when the banner
        // is suppressed/muted; keep the banner itself silent to avoid a double beep.
        content.sound = nil
        let req = UNNotificationRequest(identifier: UUID().uuidString,
                                        content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}

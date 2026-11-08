import AppKit
import SwiftUI

/// The floating HUD panel: a borderless, non-activating NSPanel hosting the SwiftUI
/// UI. It drops down from the top-right (where the notification shade lives) and is
/// toggled by the global hotkey or the menu-bar icon. Clicking outside or Escape hides it.
@MainActor
final class PanelController {
    private let panel: NSPanel
    private var outsideClickMonitor: Any?
    private var escMonitor: Any?

    private static let size = NSSize(width: 360, height: 520)

    init(store: EventStore, projects: ProjectStore) {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered, defer: false)
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let root = PanelView(store: store, projects: projects, onClose: { [weak self] in
            self?.hide()
        })
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: Self.size)
        panel.contentView = host
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        reposition()
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        installDismissMonitors()
    }

    func hide() {
        removeDismissMonitors()
        panel.orderOut(nil)
    }

    /// Anchor to the top-right of the active screen, just under the menu bar.
    private func reposition() {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let margin: CGFloat = 12
        let x = vf.maxX - Self.size.width - margin
        let y = vf.maxY - Self.size.height - margin
        panel.setFrame(NSRect(x: x, y: y, width: Self.size.width, height: Self.size.height),
                       display: true)
    }

    private func installDismissMonitors() {
        removeDismissMonitors()
        // Hide when the user clicks anywhere outside the panel.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }
        // Escape closes it.
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 { self?.hide(); return nil }  // 53 = Escape
            return event
        }
    }

    private func removeDismissMonitors() {
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m); outsideClickMonitor = nil }
        if let m = escMonitor { NSEvent.removeMonitor(m); escMonitor = nil }
    }
}

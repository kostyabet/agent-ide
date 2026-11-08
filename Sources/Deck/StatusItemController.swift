import AppKit
import Observation

/// A small menu-bar glyph that doubles as a status indicator (badges when an agent
/// needs you) and a second way to open the panel. The panel — not this — is the star.
@MainActor
final class StatusItemController {
    private let item: NSStatusItem
    private let store: EventStore
    private let onClick: () -> Void
    private var observation: Void = ()

    init(store: EventStore, onClick: @escaping () -> Void) {
        self.store = store
        self.onClick = onClick
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.action = #selector(clicked)
        item.button?.target = self
        updateIcon()
        observe()
    }

    @objc private func clicked() { onClick() }

    /// Re-read the icon whenever the store changes.
    private func observe() {
        withObservationTracking {
            _ = store.hasUnseenNeedsYou
            _ = store.anyWorking
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateIcon()
                self?.observe()
            }
        }
    }

    private func updateIcon() {
        guard let button = item.button else { return }
        let name = store.menuIcon
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        button.image = NSImage(systemSymbolName: name, accessibilityDescription: "Deck")?
            .withSymbolConfiguration(config)
        button.contentTintColor = store.hasUnseenNeedsYou ? .systemRed : nil
    }
}

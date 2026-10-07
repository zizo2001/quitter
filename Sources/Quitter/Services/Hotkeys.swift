import Foundation
import KeyboardShortcuts
import Observation

extension KeyboardShortcuts.Name {
    /// Opens/closes the panel from anywhere. No default shortcut.
    static let togglePanel = Self("togglePanel")

    /// Quits one Quit Group's running apps without opening the panel. No default shortcut.
    static func group(_ id: UUID) -> Self {
        Self("group-\(id.uuidString)")
    }
}

/// Global hotkeys: the panel toggle plus one optional shortcut per Quit Group.
@MainActor
final class Hotkeys {
    private let groups: GroupStore
    private let quitGroup: (UUID) -> Void
    private var registered: Set<UUID> = []

    init(groups: GroupStore, togglePanel: @escaping @MainActor () -> Void, quitGroup: @escaping (UUID) -> Void) {
        self.groups = groups
        self.quitGroup = quitGroup
        KeyboardShortcuts.onKeyUp(for: .togglePanel) {
            MainActor.assumeIsolated { togglePanel() }
        }
        syncGroups()
    }

    /// Registers handlers for new groups and drops handlers + stored shortcuts of deleted ones.
    private func syncGroups() {
        let current = withObservationTracking {
            Set(groups.groups.map(\.id))
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.syncGroups() }
        }
        for id in current.subtracting(registered) {
            KeyboardShortcuts.onKeyUp(for: .group(id)) { [weak self] in
                MainActor.assumeIsolated { self?.quitGroup(id) }
            }
        }
        for id in registered.subtracting(current) {
            KeyboardShortcuts.removeHandler(for: .group(id))
            KeyboardShortcuts.reset(.group(id))
        }
        registered = current
    }
}

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Opens/closes the panel from anywhere. No default shortcut.
    static let togglePanel = Self("togglePanel")
}

@MainActor
enum Hotkeys {
    static func install(togglePanel: @escaping @MainActor () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .togglePanel) {
            MainActor.assumeIsolated { togglePanel() }
        }
    }
}

import Foundation
import Observation

/// Typed scalar settings backed by UserDefaults (PLAN §5). Launch at Login is not stored here;
/// it is derived from `SMAppService` (see `LoginItem`).
@MainActor
@Observable
final class AppSettings {
    enum Key {
        static let showBackgroundApps = "showBackgroundApps"
        static let sortOrder = "sortOrder"
        static let forceQuitDelaySeconds = "forceQuitDelaySeconds"
        static let closePanelAfterQuit = "closePanelAfterQuit"
        static let confirmBeforeQuit = "confirmBeforeQuit"
        static let showUsage = "showUsage"
    }

    static let forceQuitDelayRange = 2...30

    @ObservationIgnored private let defaults: UserDefaults

    var showBackgroundApps: Bool {
        didSet { defaults.set(showBackgroundApps, forKey: Key.showBackgroundApps) }
    }
    var sortOrder: SortOrder {
        didSet { defaults.set(sortOrder.rawValue, forKey: Key.sortOrder) }
    }
    var forceQuitDelaySeconds: Int {
        didSet { defaults.set(forceQuitDelaySeconds, forKey: Key.forceQuitDelaySeconds) }
    }
    var closePanelAfterQuit: Bool {
        didSet { defaults.set(closePanelAfterQuit, forKey: Key.closePanelAfterQuit) }
    }
    var confirmBeforeQuit: Bool {
        didSet { defaults.set(confirmBeforeQuit, forKey: Key.confirmBeforeQuit) }
    }
    var showUsage: Bool {
        didSet { defaults.set(showUsage, forKey: Key.showUsage) }
    }

    /// Clamped to 2…30 s regardless of what is stored.
    var forceQuitDelay: TimeInterval {
        let range = Self.forceQuitDelayRange
        return TimeInterval(min(max(forceQuitDelaySeconds, range.lowerBound), range.upperBound))
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.showBackgroundApps: false,
            Key.sortOrder: SortOrder.name.rawValue,
            Key.forceQuitDelaySeconds: 5,
            Key.closePanelAfterQuit: true,
            Key.confirmBeforeQuit: false,
            Key.showUsage: true,
        ])
        showBackgroundApps = defaults.bool(forKey: Key.showBackgroundApps)
        sortOrder = SortOrder(rawValue: defaults.string(forKey: Key.sortOrder) ?? "") ?? .name
        forceQuitDelaySeconds = defaults.integer(forKey: Key.forceQuitDelaySeconds)
        closePanelAfterQuit = defaults.bool(forKey: Key.closePanelAfterQuit)
        confirmBeforeQuit = defaults.bool(forKey: Key.confirmBeforeQuit)
        showUsage = defaults.bool(forKey: Key.showUsage)
    }
}

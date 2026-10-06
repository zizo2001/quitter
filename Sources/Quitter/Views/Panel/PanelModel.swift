import AppKit
import Observation

/// View state for the panel: query, selection, keyboard cursor and the frozen sort order.
/// Long-lived (owned by `Dependencies`), so it survives the panel closing.
@MainActor
@Observable
final class PanelModel {
    let monitor: AppMonitor
    let settings: AppSettings
    let protected: ProtectedStore

    var query = ""
    var selection: Set<pid_t> = []
    /// Row highlighted by the keyboard cursor.
    var cursor: pid_t?
    /// Incremented to ask the view to focus the search field.
    private(set) var focusRequest = 0
    var isSearchFocused = false

    /// Usage values the current sort order was computed from. Refreshed only on panel open and
    /// membership change so rows do not jump under the cursor while sampling.
    @ObservationIgnored private var sortUsage: [pid_t: Usage] = [:]
    private var sortVersion = 0

    @ObservationIgnored var onClose: () -> Void = {}

    init(monitor: AppMonitor, settings: AppSettings, protected: ProtectedStore) {
        self.monitor = monitor
        self.settings = settings
        self.protected = protected
        trackMembership()
    }

    var visibleApps: [RunningApp] {
        _ = sortVersion
        let frozen = monitor.apps.map { app in
            var copy = app
            copy.usage = sortUsage[app.id]
            return copy
        }
        let ordered = AppFilter.apply(
            apps: frozen, protected: protected.bundleIDs, query: query, sort: settings.sortOrder
        )
        let live = Dictionary(uniqueKeysWithValues: monitor.apps.map { ($0.id, $0) })
        return ordered.compactMap { live[$0.id] }
    }

    var emptyMessage: (title: String, caption: String?) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ("Nothing to quit", "No Dock apps are running.")
        }
        return ("No apps match \u{201C}\(trimmed)\u{201D}", nil)
    }

    // MARK: Lifecycle

    func panelWillOpen() {
        monitor.rebuild()
        freezeSortOrder()
        cursor = nil
        focusRequest += 1
    }

    private func freezeSortOrder() {
        sortUsage = monitor.apps.reduce(into: [:]) { $0[$1.id] = $1.usage }
        sortVersion += 1
    }

    private func trackMembership() {
        withObservationTracking {
            _ = monitor.membershipVersion
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.freezeSortOrder()
                let live = Set(self.monitor.apps.map(\.id))
                self.selection.formIntersection(live)
                if let cursor = self.cursor, !live.contains(cursor) { self.cursor = nil }
                self.trackMembership()
            }
        }
    }

    // MARK: Selection

    func toggle(_ pid: pid_t) {
        if selection.contains(pid) {
            selection.remove(pid)
        } else {
            selection.insert(pid)
        }
    }

    // MARK: Keyboard

    /// Returns true when the key was consumed.
    func handleKey(_ key: KeyPress) -> Bool {
        switch key.code {
        case KeyPress.escape:
            if query.isEmpty {
                onClose()
            } else {
                query = ""
            }
            return true
        default:
            return false
        }
    }
}

import AppKit
import Observation
import SwiftUI

/// View state for the panel: query, selection, keyboard cursor and the frozen sort order.
/// Long-lived (owned by `Dependencies`), so it survives the panel closing.
@MainActor
@Observable
final class PanelModel {
    let monitor: AppMonitor
    let settings: AppSettings
    let protected: ProtectedStore
    let coordinator: QuitCoordinator

    var query = "" {
        didSet {
            guard query != oldValue else { return }
            cursor = query.isEmpty ? nil : visibleApps.first?.id
        }
    }
    var selection: Set<pid_t> = []
    /// Row highlighted by the keyboard cursor.
    var cursor: pid_t?
    /// Apps awaiting confirmation when "Ask before quitting" is on.
    var confirming: [RunningApp]?
    /// Incremented to ask the view to focus the search field.
    private(set) var focusRequest = 0
    var isSearchFocused = false

    /// Usage values the current sort order was computed from. Refreshed only on panel open and
    /// membership change so rows do not jump under the cursor while sampling.
    @ObservationIgnored private var sortUsage: [pid_t: Usage] = [:]
    private var sortVersion = 0

    @ObservationIgnored var onClose: () -> Void = {}
    @ObservationIgnored var onOpenSettings: () -> Void = {}

    init(monitor: AppMonitor, settings: AppSettings, protected: ProtectedStore, coordinator: QuitCoordinator) {
        self.monitor = monitor
        self.settings = settings
        self.protected = protected
        self.coordinator = coordinator
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

    /// Selected, still-running, unprotected apps that are not already being quit.
    var quitTargets: [RunningApp] {
        AppFilter.apply(apps: monitor.apps, protected: protected.bundleIDs, query: "", sort: .name)
            .filter { selection.contains($0.id) && !coordinator.state(for: $0.id).isPending }
    }

    // MARK: Lifecycle

    func panelWillOpen() {
        monitor.rebuild()
        freezeSortOrder()
        cursor = query.isEmpty ? nil : visibleApps.first?.id
        focusRequest += 1
    }

    func freezeSortOrder() {
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
        guard !coordinator.state(for: pid).isPending else { return }
        withAnimation(.snappy) {
            if selection.contains(pid) {
                selection.remove(pid)
            } else {
                selection.insert(pid)
            }
        }
    }

    func selectAllVisible() {
        let pids = visibleApps.map(\.id).filter { !coordinator.state(for: $0).isPending }
        withAnimation(.snappy) { selection.formUnion(pids) }
    }

    func selectNone() {
        withAnimation(.snappy) { selection.removeAll() }
    }

    // MARK: Quitting

    func requestQuit() {
        let targets = quitTargets
        guard !targets.isEmpty else { return }
        if settings.confirmBeforeQuit {
            confirming = targets
        } else {
            performQuit(targets)
        }
    }

    func confirmQuit() {
        guard let targets = confirming else { return }
        confirming = nil
        performQuit(targets)
    }

    func cancelConfirmation() {
        confirming = nil
    }

    private func performQuit(_ targets: [RunningApp]) {
        selection.removeAll()
        coordinator.quit(pids: targets.map(\.id))
    }

    func forceQuit(_ pid: pid_t) {
        coordinator.forceQuit(pid: pid)
    }

    // MARK: Keyboard

    /// Returns true when the key was consumed.
    func handleKey(_ key: KeyPress) -> Bool {
        if confirming != nil {
            switch key.code {
            case KeyPress.escape: cancelConfirmation()
            case KeyPress.returnKey, KeyPress.keypadEnter: confirmQuit()
            default: break
            }
            return true
        }
        if key.command {
            switch key.characters {
            case "a":
                key.shift ? selectNone() : selectAllVisible()
                return true
            case ",":
                onOpenSettings()
                return true
            default:
                return false
            }
        }
        switch key.code {
        case KeyPress.escape:
            if query.isEmpty { onClose() } else { query = "" }
            return true
        case KeyPress.upArrow:
            moveCursor(by: -1)
            return true
        case KeyPress.downArrow:
            moveCursor(by: 1)
            return true
        case KeyPress.returnKey, KeyPress.keypadEnter:
            requestQuit()
            return true
        case KeyPress.space:
            guard let cursor else { return false }
            toggle(cursor)
            return true
        default:
            break
        }
        if !isSearchFocused, !key.control, !key.option, let scalar = key.characters.unicodeScalars.first,
           !CharacterSet.controlCharacters.contains(scalar),
           !(0xF700...0xF8FF).contains(scalar.value) { // AppKit function-key range
            query += key.characters
            focusRequest += 1
            return true
        }
        return false
    }

    private func moveCursor(by step: Int) {
        let pids = visibleApps.map(\.id)
        guard !pids.isEmpty else { return }
        let next: Int
        if let cursor, let index = pids.firstIndex(of: cursor) {
            next = (index + step + pids.count) % pids.count
        } else {
            next = step > 0 ? 0 : pids.count - 1
        }
        cursor = pids[next]
    }
}

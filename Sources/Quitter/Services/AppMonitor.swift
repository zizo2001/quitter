import AppKit
import Combine
import Observation

/// Mirrors `NSWorkspace.runningApplications` as `[RunningApp]` values.
/// `NSRunningApplication` objects stay private here; views only see values.
@MainActor
@Observable
final class AppMonitor {
    private(set) var apps: [RunningApp] = []
    /// Bumped whenever the set of listed pids changes (not on usage updates).
    private(set) var membershipVersion = 0

    @ObservationIgnored private var running: [pid_t: NSRunningApplication] = [:]
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let ownPID = ProcessInfo.processInfo.processIdentifier
    @ObservationIgnored private var kvo: AnyCancellable?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var rebuildScheduled = false

    init(settings: AppSettings) {
        self.settings = settings
        observeWorkspace()
        trackSettings()
        rebuild()
    }

    func runningApplication(for pid: pid_t) -> NSRunningApplication? {
        running[pid]
    }

    /// Writes sampled usage into the matching rows. Does not change membership.
    func apply(usage: [pid_t: Usage]) {
        for index in apps.indices {
            if let value = usage[apps[index].id] {
                apps[index].usage = value
            }
        }
    }

    func rebuild() {
        rebuildScheduled = false
        let previousUsage = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0.usage) })
        let includeAccessory = settings.showBackgroundApps
        let candidates = NSWorkspace.shared.runningApplications.filter { app in
            guard app.processIdentifier != ownPID, !app.isTerminated else { return false }
            switch app.activationPolicy {
            case .regular: return true
            case .accessory: return includeAccessory
            case .prohibited: return false
            @unknown default: return false
            }
        }
        .sorted { ($0.launchDate ?? .distantPast, $0.processIdentifier) < ($1.launchDate ?? .distantPast, $1.processIdentifier) }

        var newRunning: [pid_t: NSRunningApplication] = [:]
        var seen: [String: Int] = [:]
        var newApps: [RunningApp] = []
        for app in candidates {
            let pid = app.processIdentifier
            newRunning[pid] = app
            var name = app.localizedName ?? app.bundleIdentifier ?? "PID \(pid)"
            if let bundleID = app.bundleIdentifier {
                let count = (seen[bundleID] ?? 0) + 1
                seen[bundleID] = count
                if count > 1 { name += " (\(count))" }
            }
            newApps.append(RunningApp(
                id: pid,
                bundleID: app.bundleIdentifier,
                name: name,
                icon: app.icon ?? NSWorkspace.shared.icon(for: .application),
                launchDate: app.launchDate,
                policy: app.activationPolicy,
                usage: previousUsage[pid] ?? nil
            ))
        }

        let membershipChanged = Set(newRunning.keys) != Set(running.keys)
        running = newRunning
        if newApps != apps { apps = newApps }
        if membershipChanged { membershipVersion += 1 }
    }

    private func scheduleRebuild() {
        guard !rebuildScheduled else { return }
        rebuildScheduled = true
        Task { @MainActor [weak self] in self?.rebuild() }
    }

    private func observeWorkspace() {
        kvo = NSWorkspace.shared.publisher(for: \.runningApplications)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self?.scheduleRebuild() }
                }
            }
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
        ]
        for name in names {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleRebuild() }
            })
        }
    }

    private func trackSettings() {
        withObservationTracking {
            _ = settings.showBackgroundApps
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.rebuild()
                self?.trackSettings()
            }
        }
    }
}

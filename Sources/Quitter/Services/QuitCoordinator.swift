import AppKit
import Observation

@MainActor
protocol Terminating {
    func terminate(pid: pid_t) -> Bool
    func forceTerminate(pid: pid_t) -> Bool
    func isRunning(pid: pid_t) -> Bool
}

@MainActor
protocol NowProviding {
    var now: Date { get }
}

struct SystemNow: NowProviding {
    var now: Date { Date() }
}

/// Real `Terminating` over `NSRunningApplication`, looked up fresh by pid each call.
struct WorkspaceTerminator: Terminating {
    func terminate(pid: pid_t) -> Bool {
        NSRunningApplication(processIdentifier: pid)?.terminate() ?? false
    }

    func forceTerminate(pid: pid_t) -> Bool {
        NSRunningApplication(processIdentifier: pid)?.forceTerminate() ?? false
    }

    func isRunning(pid: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return false }
        return !app.isTerminated
    }
}

/// Sends quits, watches for exits, escalates to `.stuck` after the force-quit delay.
/// Long-lived: state survives the panel closing (e.g. when a save sheet steals focus).
@MainActor
@Observable
final class QuitCoordinator {
    static let pollInterval: Duration = .milliseconds(500)
    static let exitAnimation: TimeInterval = Tokens.Motion.rowExit
    /// Absorbs floating-point drift in Date arithmetic.
    private static let epsilon: TimeInterval = 0.001

    private(set) var states: [pid_t: QuitState] = [:]
    /// Rows in `.requested` or `.stuck`.
    private(set) var pendingCount = 0

    @ObservationIgnored var onPendingCountChange: (_ old: Int, _ new: Int) -> Void = { _, _ in }

    @ObservationIgnored private let terminator: Terminating
    @ObservationIgnored private let clock: NowProviding
    @ObservationIgnored private let forceQuitDelay: () -> TimeInterval
    @ObservationIgnored private let autoPoll: Bool
    @ObservationIgnored private var terminatedAt: [pid_t: Date] = [:]
    @ObservationIgnored private var pollTask: Task<Void, Never>?

    init(
        terminator: Terminating,
        clock: NowProviding = SystemNow(),
        forceQuitDelay: @escaping () -> TimeInterval,
        autoPoll: Bool = true
    ) {
        self.terminator = terminator
        self.clock = clock
        self.forceQuitDelay = forceQuitDelay
        self.autoPoll = autoPoll
    }

    func state(for pid: pid_t) -> QuitState {
        states[pid] ?? .idle
    }

    func quit(pids: some Sequence<pid_t>) {
        let now = clock.now
        for pid in pids where !state(for: pid).isPending {
            if terminator.terminate(pid: pid) {
                states[pid] = .requested(at: now)
            } else {
                NSLog("Quitter: terminate() returned false for pid \(pid); marking stuck")
                states[pid] = .stuck
            }
        }
        update()
    }

    /// Only ever called from an explicit click on that row's Force Quit button.
    func forceQuit(pid: pid_t) {
        guard state(for: pid) == .stuck else { return }
        states[pid] = terminator.forceTerminate(pid: pid) ? .requested(at: clock.now) : .stuck
        update()
    }

    /// One poll step: exits → `.terminated`, timeouts → `.stuck`, finished exits removed.
    func tick() {
        let now = clock.now
        let delay = forceQuitDelay()
        for (pid, state) in states {
            switch state {
            case .requested(let at):
                if !terminator.isRunning(pid: pid) {
                    markTerminated(pid, at: now)
                } else if now.timeIntervalSince(at) >= delay - Self.epsilon {
                    states[pid] = .stuck
                }
            case .stuck:
                if !terminator.isRunning(pid: pid) { markTerminated(pid, at: now) }
            case .terminated:
                if now.timeIntervalSince(terminatedAt[pid] ?? now) >= Self.exitAnimation - Self.epsilon {
                    states[pid] = nil
                    terminatedAt[pid] = nil
                }
            case .idle:
                states[pid] = nil
            }
        }
        update()
    }

    private func markTerminated(_ pid: pid_t, at now: Date) {
        states[pid] = .terminated
        terminatedAt[pid] = now
    }

    private func update() {
        let old = pendingCount
        let new = states.values.filter(\.isPending).count
        if new != old {
            pendingCount = new
            onPendingCountChange(old, new)
        }
        startPollingIfNeeded()
    }

    private var needsPolling: Bool {
        !states.isEmpty
    }

    private func startPollingIfNeeded() {
        guard autoPoll, pollTask == nil, needsPolling else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pollInterval)
                guard let self else { return }
                self.tick()
                if !self.needsPolling {
                    self.pollTask = nil
                    return
                }
            }
        }
    }
}

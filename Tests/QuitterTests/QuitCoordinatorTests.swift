import Foundation
import Testing
@testable import Quitter

@MainActor
private final class FakeTerminator: Terminating {
    var running: Set<pid_t>
    var refusesTerminate: Set<pid_t> = []
    /// Pids that exit as soon as they receive a normal terminate.
    var exitsOnTerminate: Set<pid_t> = []
    private(set) var terminated: [pid_t] = []
    private(set) var forced: [pid_t] = []

    init(running: Set<pid_t>) { self.running = running }

    func terminate(pid: pid_t) -> Bool {
        terminated.append(pid)
        if refusesTerminate.contains(pid) { return false }
        if exitsOnTerminate.contains(pid) { running.remove(pid) }
        return true
    }

    func forceTerminate(pid: pid_t) -> Bool {
        forced.append(pid)
        running.remove(pid)
        return true
    }

    func isRunning(pid: pid_t) -> Bool { running.contains(pid) }
}

@MainActor
private final class FakeClock: NowProviding {
    var now = Date(timeIntervalSince1970: 1_000)
    func advance(_ seconds: TimeInterval) { now += seconds }
}

@MainActor
struct QuitCoordinatorTests {
    private func make(_ terminator: FakeTerminator, _ clock: FakeClock, delay: TimeInterval = 5) -> QuitCoordinator {
        QuitCoordinator(terminator: terminator, clock: clock, forceQuitDelay: { delay }, autoPoll: false)
    }

    @Test func quitMovesToRequestedThenTerminatedThenRemoved() {
        let terminator = FakeTerminator(running: [1, 2])
        let clock = FakeClock()
        let coordinator = make(terminator, clock)
        coordinator.quit(pids: [1, 2])
        #expect(coordinator.state(for: 1) == .requested(at: clock.now))
        #expect(coordinator.pendingCount == 2)

        terminator.running = []
        clock.advance(0.5)
        coordinator.tick()
        #expect(coordinator.state(for: 1) == .terminated)
        #expect(coordinator.pendingCount == 0)

        clock.advance(0.3)
        coordinator.tick()
        #expect(coordinator.states.isEmpty)
    }

    @Test func terminateReturningFalseIsStuckImmediately() {
        let terminator = FakeTerminator(running: [7])
        terminator.refusesTerminate = [7]
        let coordinator = make(terminator, FakeClock())
        coordinator.quit(pids: [7])
        #expect(coordinator.state(for: 7) == .stuck)
        #expect(coordinator.pendingCount == 1)
    }

    @Test func escalatesToStuckAfterDelay() {
        let terminator = FakeTerminator(running: [3])
        let clock = FakeClock()
        let coordinator = make(terminator, clock, delay: 5)
        coordinator.quit(pids: [3])
        clock.advance(4.9)
        coordinator.tick()
        #expect(coordinator.state(for: 3) == .requested(at: clock.now - 4.9))
        clock.advance(0.1)
        coordinator.tick()
        #expect(coordinator.state(for: 3) == .stuck)
        #expect(terminator.forced.isEmpty, "never force-quits on its own")
    }

    @Test func forceQuitOnlyFromStuckAndWaitsForPoll() {
        let terminator = FakeTerminator(running: [4])
        let clock = FakeClock()
        let coordinator = make(terminator, clock)
        coordinator.quit(pids: [4])
        coordinator.forceQuit(pid: 4)
        #expect(terminator.forced.isEmpty, "requested rows cannot be force-quit")

        clock.advance(5)
        coordinator.tick()
        coordinator.forceQuit(pid: 4)
        #expect(terminator.forced == [4])
        #expect(coordinator.state(for: 4) == .requested(at: clock.now))

        clock.advance(0.5)
        coordinator.tick()
        #expect(coordinator.state(for: 4) == .terminated)
    }

    @Test func pendingCountCallbackFiresOnTransitions() {
        let terminator = FakeTerminator(running: [5, 6])
        let clock = FakeClock()
        let coordinator = make(terminator, clock)
        var changes: [[Int]] = []
        coordinator.onPendingCountChange = { changes.append([$0, $1]) }
        coordinator.quit(pids: [5, 6])
        terminator.running = [6]
        coordinator.tick()
        terminator.running = []
        coordinator.tick()
        #expect(changes == [[0, 2], [2, 1], [1, 0]])
    }

    @Test func appExitingWhileStuckIsTerminated() {
        let terminator = FakeTerminator(running: [8])
        terminator.refusesTerminate = [8]
        let coordinator = make(terminator, FakeClock())
        coordinator.quit(pids: [8])
        terminator.running = []
        coordinator.tick()
        #expect(coordinator.state(for: 8) == .terminated)
    }

    @Test func requittingPendingPidIsIgnored() {
        let terminator = FakeTerminator(running: [9])
        let coordinator = make(terminator, FakeClock())
        coordinator.quit(pids: [9])
        coordinator.quit(pids: [9])
        #expect(terminator.terminated == [9])
    }
}

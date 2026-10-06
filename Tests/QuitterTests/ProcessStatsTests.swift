import Foundation
import Testing
@testable import Quitter

struct ProcessStatsTests {
    @Test func cpuPercentFromDeltas() {
        // 1 s of CPU over 2 s of wall time = 50 %.
        #expect(ProcessStats.cpuPercent(previousNanos: 0, currentNanos: 1_000_000_000, elapsedNanos: 2_000_000_000) == 50)
        // Multi-core: 3 s of CPU in 1 s = 300 %, not capped.
        #expect(ProcessStats.cpuPercent(previousNanos: 1_000, currentNanos: 3_000_001_000, elapsedNanos: 1_000_000_000) == 300)
    }

    @Test func cpuPercentClampsAtZero() {
        // A helper process exited, so the summed counter went down.
        #expect(ProcessStats.cpuPercent(previousNanos: 500, currentNanos: 100, elapsedNanos: 1_000) == 0)
        #expect(ProcessStats.cpuPercent(previousNanos: 0, currentNanos: 100, elapsedNanos: 0) == 0)
    }

    @Test func firstSampleHasNoDeltaThenSecondDoes() throws {
        let first = UsageSampler.compute(
            samples: [42: .init(footprint: 1_000, cpuNanos: 5_000_000_000)],
            wallNanos: 10_000_000_000,
            baselines: [:]
        )
        #expect(first.usage[42] == Usage(memoryBytes: 1_000, cpuPercent: 0, isFirstSample: true))

        let second = UsageSampler.compute(
            samples: [42: .init(footprint: 2_000, cpuNanos: 6_800_000_000)],
            wallNanos: 12_000_000_000,
            baselines: first.baselines
        )
        let usage = try #require(second.usage[42])
        #expect(usage.memoryBytes == 2_000)
        #expect(!usage.isFirstSample)
        #expect(abs(usage.cpuPercent - 90) < 0.0001)
    }

    @Test func goneProcessesDropOutOfBaselines() {
        let result = UsageSampler.compute(
            samples: [1: .init(footprint: 1, cpuNanos: 1)],
            wallNanos: 2,
            baselines: [1: .init(cpuNanos: 0, wallNanos: 1), 2: .init(cpuNanos: 0, wallNanos: 1)]
        )
        #expect(result.baselines.keys.sorted() == [1])
    }

    @Test func readsOwnProcessAndSpawnedChild() throws {
        let own = ProcessInfo.processInfo.processIdentifier
        #expect((ProcessStats.footprint(pid: own) ?? 0) > 1_000_000)
        #expect(ProcessStats.cpuTimeNanos(pid: own) != nil)

        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["5"]
        try child.run()
        defer { child.terminate() }
        #expect(ProcessStats.descendants(of: own).contains(child.processIdentifier))

        let tree = try #require(ProcessStats.sampleTree(pid: own))
        #expect(tree.footprint >= (ProcessStats.footprint(pid: own) ?? 0))
    }

    @Test func machConversionIsMonotonic() {
        #expect(ProcessStats.machToNanos(0) == 0)
        #expect(ProcessStats.machToNanos(24_000_000) >= ProcessStats.machToNanos(1_000))
    }
}

import Foundation

/// Samples memory/CPU every 2 s while the panel is visible. Sampling runs off the main actor
/// over a `[pid_t]` snapshot; results are applied to `AppMonitor` on the main actor.
@MainActor
final class UsageSampler {
    static let interval: Duration = .seconds(2)

    struct Baseline: Sendable, Equatable {
        let cpuNanos: UInt64
        let wallNanos: UInt64
    }

    private let monitor: AppMonitor
    private var task: Task<Void, Never>?
    private var baselines: [pid_t: Baseline] = [:]
    /// Called after the first sample following `start()`, so the panel can sort on fresh numbers.
    var onFirstSample: () -> Void = {}

    init(monitor: AppMonitor) {
        self.monitor = monitor
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            var first = true
            while !Task.isCancelled {
                guard let self else { return }
                await self.sampleOnce()
                if first {
                    first = false
                    self.onFirstSample()
                }
                try? await Task.sleep(for: Self.interval)
            }
        }
    }

    /// Stops sampling and drops CPU baselines: a delta spanning the time the panel was hidden
    /// would be an average, not current load.
    func stop() {
        task?.cancel()
        task = nil
        baselines = [:]
    }

    private func sampleOnce() async {
        let pids = monitor.apps.map(\.id)
        let (samples, wall) = await Task.detached(priority: .utility) {
            Self.collect(pids: pids)
        }.value
        guard !Task.isCancelled else { return }
        let (usage, next) = Self.compute(samples: samples, wallNanos: wall, baselines: baselines)
        baselines = next
        monitor.apply(usage: usage)
    }

    nonisolated private static func collect(pids: [pid_t]) -> ([pid_t: ProcessStats.Sample], UInt64) {
        var samples: [pid_t: ProcessStats.Sample] = [:]
        for pid in pids {
            samples[pid] = ProcessStats.sampleTree(pid: pid)
        }
        return (samples, DispatchTime.now().uptimeNanoseconds)
    }

    /// Pure: turns raw cumulative counters into `Usage`, given the previous baselines.
    nonisolated static func compute(
        samples: [pid_t: ProcessStats.Sample],
        wallNanos: UInt64,
        baselines: [pid_t: Baseline]
    ) -> (usage: [pid_t: Usage], baselines: [pid_t: Baseline]) {
        var usage: [pid_t: Usage] = [:]
        var next: [pid_t: Baseline] = [:]
        for (pid, sample) in samples {
            next[pid] = Baseline(cpuNanos: sample.cpuNanos, wallNanos: wallNanos)
            if let previous = baselines[pid], wallNanos > previous.wallNanos {
                let percent = ProcessStats.cpuPercent(
                    previousNanos: previous.cpuNanos,
                    currentNanos: sample.cpuNanos,
                    elapsedNanos: wallNanos - previous.wallNanos
                )
                usage[pid] = Usage(memoryBytes: sample.footprint, cpuPercent: percent, isFirstSample: false)
            } else {
                usage[pid] = Usage(memoryBytes: sample.footprint, cpuPercent: 0, isFirstSample: true)
            }
        }
        return (usage, next)
    }
}

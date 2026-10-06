import Darwin

/// libproc wrappers. Numbers match Activity Monitor: memory is `ri_phys_footprint`,
/// CPU is user + system time. Works without privileges for same-user processes.
enum ProcessStats {
    /// Raw cumulative counters for one app: the pid plus all its descendants.
    struct Sample: Sendable, Equatable {
        let footprint: UInt64
        let cpuNanos: UInt64
    }

    static func footprint(pid: pid_t) -> UInt64? {
        rusage(pid: pid)?.ri_phys_footprint
    }

    /// `ri_user_time + ri_system_time`, converted from Mach absolute units to nanoseconds.
    static func cpuTimeNanos(pid: pid_t) -> UInt64? {
        guard let info = rusage(pid: pid) else { return nil }
        return machToNanos(info.ri_user_time &+ info.ri_system_time)
    }

    /// Children, grandchildren, … (depth ≤ 6) via `proc_listchildpids`.
    static func descendants(of pid: pid_t, maxDepth: Int = 6) -> [pid_t] {
        var result: [pid_t] = []
        var frontier = [pid]
        for _ in 0..<maxDepth where !frontier.isEmpty {
            var next: [pid_t] = []
            for parent in frontier {
                next.append(contentsOf: children(of: parent))
            }
            result.append(contentsOf: next)
            frontier = next
        }
        return result
    }

    /// Footprint and CPU time summed over `pid` and its descendants. Nil if `pid` is unreadable.
    static func sampleTree(pid: pid_t) -> Sample? {
        guard let root = rusage(pid: pid) else { return nil }
        var footprint = root.ri_phys_footprint
        var cpu = root.ri_user_time &+ root.ri_system_time
        for child in descendants(of: pid) {
            guard let info = rusage(pid: child) else { continue }
            footprint &+= info.ri_phys_footprint
            cpu &+= info.ri_user_time &+ info.ri_system_time
        }
        return Sample(footprint: footprint, cpuNanos: machToNanos(cpu))
    }

    /// Activity-Monitor-style CPU % over one interval. Clamped at 0, not capped at 100.
    static func cpuPercent(previousNanos: UInt64, currentNanos: UInt64, elapsedNanos: UInt64) -> Double {
        guard elapsedNanos > 0, currentNanos > previousNanos else { return 0 }
        return Double(currentNanos - previousNanos) / Double(elapsedNanos) * 100
    }

    static func machToNanos(_ value: UInt64) -> UInt64 {
        let (numer, denom) = timebase
        guard numer != denom else { return value }
        let product = value.multipliedFullWidth(by: UInt64(numer))
        return UInt64(denom).dividingFullWidth(product).quotient
    }

    private static let timebase: (numer: UInt32, denom: UInt32) = {
        var info = mach_timebase_info_data_t()
        guard mach_timebase_info(&info) == KERN_SUCCESS, info.denom != 0 else { return (1, 1) }
        return (info.numer, info.denom)
    }()

    private static func rusage(pid: pid_t) -> rusage_info_v4? {
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        return result == 0 ? info : nil
    }

    private static func children(of pid: pid_t) -> [pid_t] {
        var capacity = 64
        while capacity <= 8192 {
            var buffer = [pid_t](repeating: 0, count: capacity)
            let count = buffer.withUnsafeMutableBytes {
                proc_listchildpids(pid, $0.baseAddress, Int32($0.count))
            }
            guard count >= 0 else { return [] }
            if Int(count) < capacity {
                return Array(buffer.prefix(Int(count))).filter { $0 > 0 }
            }
            capacity *= 4
        }
        return []
    }
}

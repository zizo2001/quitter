import AppKit

/// Value shown in the panel list. Main-actor only (holds an NSImage).
struct RunningApp: Identifiable, Hashable {
    let id: pid_t
    let bundleID: String?
    /// Display name, already suffixed " (2)" for a second instance of one bundle.
    let name: String
    let icon: NSImage
    let launchDate: Date?
    let policy: NSApplication.ActivationPolicy
    var usage: Usage?
}

struct Usage: Hashable, Sendable {
    /// Physical footprint of the process and all its descendants.
    let memoryBytes: UInt64
    /// Activity-Monitor-style CPU %, may exceed 100 on multi-core.
    let cpuPercent: Double
    /// True for the first sample of a pid: there is no delta yet, so CPU shows "—".
    let isFirstSample: Bool
}

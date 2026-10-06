import AppKit

/// Single composition root: creates every long-lived service once.
@MainActor
final class Dependencies {
    let statusBar: StatusBarController

    init() {
        statusBar = StatusBarController()
    }
}

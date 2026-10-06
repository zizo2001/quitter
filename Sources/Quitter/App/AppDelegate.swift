import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var dependencies: Dependencies?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // No Dock icon even when run without a bundle (swift run).
        app.setActivationPolicy(.accessory)
        #if DEBUG
        // Verification aid: lets UI-automation tools that only index regular apps see Quitter.
        if ProcessInfo.processInfo.environment["QUITTER_REGULAR_POLICY"] == "1" {
            app.setActivationPolicy(.regular)
        }
        #endif
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        dependencies = Dependencies()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

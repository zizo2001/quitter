import AppKit
import SwiftUI

/// Owns the single Settings window. Opening activates Quitter so the window is not hidden behind
/// other apps (LSUIElement apps otherwise open windows in the background).
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let dependencies: SettingsDependencies
    private var window: NSWindow?

    init(dependencies: SettingsDependencies) {
        self.dependencies = dependencies
    }

    func show(pane: SettingsPane? = nil) {
        let window = window ?? makeWindow()
        self.window = window
        if let pane { dependencies.navigation.selection = pane }
        dependencies.loginItem.refresh()
        // Cooperative `NSApp.activate()` is refused when Settings is opened by ⌘, from the
        // non-activating panel while another app is active (logged isActive=false). The legacy
        // call still brings the window forward.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = SettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 460),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Quitter Settings"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 600, height: 400)
        window.delegate = self
        let hosting = NSHostingView(rootView: SettingsView(dependencies: dependencies))
        hosting.sizingOptions = []
        window.contentView = hosting
        window.setContentSize(NSSize(width: 680, height: 460))
        if !window.setFrameUsingName(Self.autosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(Self.autosaveName)
        return window
    }

    private static let autosaveName = "QuitterSettings"
}

/// Quitter has no main menu (LSUIElement), so standard window shortcuts are handled here.
private final class SettingsWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command, event.charactersIgnoringModifiers == "w" {
            performClose(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

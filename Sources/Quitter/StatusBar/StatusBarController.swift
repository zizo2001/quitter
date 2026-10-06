import AppKit
import SwiftUI

/// Owns the status item and the panel: icon state, right-click menu, open/close.
@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let panel = PanelWindow()
    private var eventMonitors: [Any] = []
    private var resignObserver: NSObjectProtocol?
    private var lastAutoClose: Date = .distantPast

    var isPanelVisible: Bool { panel.isVisible && !panel.isClosing }

    private let model: PanelModel
    private let settings: AppSettings
    private let sampler: UsageSampler

    init(model: PanelModel, settings: AppSettings, sampler: UsageSampler) {
        self.model = model
        self.settings = settings
        self.sampler = sampler
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureButton()
        model.onClose = { [weak self] in self?.closePanel() }
        model.coordinator.onPendingCountChange = { [weak self] old, new in
            self?.pendingCountChanged(from: old, to: new)
        }
        let host = NSHostingView(rootView: PanelView(model: model) { [weak self] height in
            self?.panel.setContentHeight(height)
        })
        host.sizingOptions = []
        panel.setRootView(host)
    }

    // MARK: Status item

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = Self.icon(pending: false)
        button.toolTip = "Quitter"
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        button.setAccessibilityLabel("Quitter")
    }

    static func icon(pending: Bool) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let image = NSImage(
            systemSymbolName: pending ? "xmark.circle.fill" : "xmark.circle",
            accessibilityDescription: "Quitter"
        )?.withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

    /// Filled icon while quits are pending; close the panel 0.6 s after the last one finishes.
    private func pendingCountChanged(from old: Int, to new: Int) {
        statusItem.button?.image = Self.icon(pending: new > 0)
        guard old > 0, new == 0, settings.closePanelAfterQuit else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard let self, self.model.coordinator.pendingCount == 0, self.isPanelVisible else { return }
            self.closePanel()
        }
    }

    /// Set by `Dependencies`: open Settings, read/toggle Launch at Login.
    var onOpenSettings: () -> Void = {}
    var loginItem: LoginItem?

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseDown {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    private func showContextMenu() {
        closePanel()
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Quitter", action: #selector(menuOpenPanel), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(menuOpenSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        let login = menu.addItem(withTitle: "Launch at Login", action: #selector(menuToggleLogin), keyEquivalent: "")
        loginItem?.refresh()
        login.state = loginItem?.isEnabled == true ? .on : .off
        if loginItem?.isAvailable != true {
            login.action = nil
            login.toolTip = "Available when installed"
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Quitter", action: #selector(menuQuit), keyEquivalent: "q")
        for item in menu.items where item.action != nil {
            item.target = self
        }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func menuOpenPanel() {
        showPanel()
    }

    @objc private func menuOpenSettings() {
        onOpenSettings()
    }

    @objc private func menuToggleLogin() {
        guard let loginItem else { return }
        loginItem.set(!loginItem.isEnabled)
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }

    // MARK: Panel

    func togglePanel() {
        if isPanelVisible {
            closePanel()
        } else if Date().timeIntervalSince(lastAutoClose) > 0.25 {
            // A click on the status item first resigns key / trips the outside-click
            // monitor; without this guard that same click would reopen the panel.
            showPanel()
        }
    }

    func showPanel() {
        guard !isPanelVisible else { return }
        model.panelWillOpen()
        panel.present(topCenter: panelTopCenter())
        installMonitors()
        sampler.start()
    }

    func closePanel() {
        sampler.stop()
        removeMonitors()
        panel.dismiss()
    }

    private func autoClose() {
        lastAutoClose = Date()
        closePanel()
    }

    /// Centred under the status button, 6 pt below the menu bar, on the button's screen.
    /// Falls back to the top-right of the main screen when the button is hidden.
    private func panelTopCenter() -> NSPoint {
        let half = Tokens.Size.panelWidth / 2
        if let button = statusItem.button, let window = button.window,
           let screen = window.screen, window.occlusionState.contains(.visible),
           !button.isHidden {
            let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
            let visible = screen.visibleFrame
            let x = min(max(rect.midX, visible.minX + half + 8), visible.maxX - half - 8)
            return NSPoint(x: x, y: min(rect.minY, visible.maxY) - 6)
        }
        let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? .zero
        return NSPoint(x: visible.maxX - 12 - half, y: visible.maxY - 12)
    }

    // MARK: Event monitors

    private func installMonitors() {
        removeMonitors()
        let buttonWindow = statusItem.button?.window
        if let global = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown],
            handler: { [weak self] _ in
                MainActor.assumeIsolated { self?.autoClose() }
            }
        ) {
            eventMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown],
            handler: { [weak self] event in
                let window = event.window
                MainActor.assumeIsolated {
                    guard let self, let window else { return }
                    // Our own menus (⋯ menu, submenus) are pop-up level windows: not "outside".
                    if window !== self.panel && window !== buttonWindow && window.level == .normal {
                        self.autoClose()
                    }
                }
                return event
            }
        ) {
            eventMonitors.append(local)
        }
        if let keys = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown,
            handler: { [weak self] event in
                let key = KeyPress(event)
                let window = event.window
                let consumed = MainActor.assumeIsolated {
                    guard let self, window === self.panel else { return false }
                    return self.handleKey(key)
                }
                return consumed ? nil : event
            }
        ) {
            eventMonitors.append(keys)
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.autoClose() }
        }
    }

    private func removeMonitors() {
        eventMonitors.forEach(NSEvent.removeMonitor)
        eventMonitors.removeAll()
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
        }
        resignObserver = nil
    }

    /// Returns true when the key was consumed.
    private func handleKey(_ key: KeyPress) -> Bool {
        model.handleKey(key)
    }
}

import AppKit
import Observation

/// Hides chosen menu bar icons and shows them again with one click.
///
/// Two status items of our own: a chevron (toggle) and a thin divider to its left. Chosen icons
/// are ⌘-dragged to the left of the divider. Hiding widens the divider until it reaches the
/// screen's left edge, so macOS 27 pushes everything left of it out of the menu bar; revealing
/// shrinks it back. Nothing polls: the only work happens on a click, a display change, or when
/// the user changes the list in Settings.
@MainActor
@Observable
final class MenuBarHider {
    enum Key {
        static let enabled = "menuBarHiderEnabled"
        static let hiddenIDs = "menuBarHiddenItems"
        static let autoHide = "menuBarAutoHideSeconds"
        /// hidden item ID → ID of the icon that was right of it, so un-hiding puts it back.
        static let neighbours = "menuBarHiddenNeighbours"
    }

    nonisolated static let dividerLength: CGFloat = 12
    static let autoHideChoices = [0, 5, 10, 30]

    private(set) var isEnabled: Bool
    private(set) var isRevealed = true
    private(set) var hiddenIDs: Set<String>
    /// Seconds before revealed icons hide again; 0 = never.
    var autoHideSeconds: Int {
        didSet { defaults.set(autoHideSeconds, forKey: Key.autoHide) }
    }
    /// True while an icon is being moved (Settings disables its toggles meanwhile).
    private(set) var isMoving = false

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var toggleItem: NSStatusItem?
    @ObservationIgnored private var dividerItem: NSStatusItem?
    @ObservationIgnored private var autoHideTask: Task<Void, Never>?
    @ObservationIgnored private var screenObserver: NSObjectProtocol?
    /// Quitter's own menu bar icon, which must never end up on the hidden side.
    @ObservationIgnored private weak var ownItem: NSStatusItem?

    init(ownItem: NSStatusItem?, defaults: UserDefaults = .standard) {
        self.ownItem = ownItem
        self.defaults = defaults
        defaults.register(defaults: [Key.enabled: false, Key.autoHide: 10])
        isEnabled = defaults.bool(forKey: Key.enabled)
        hiddenIDs = Set(defaults.stringArray(forKey: Key.hiddenIDs) ?? [])
        autoHideSeconds = defaults.integer(forKey: Key.autoHide)
        if isEnabled {
            installItems()
            Task { [weak self] in
                // Let the menu bar lay out the new items, fix our own icon, then hide.
                try? await Task.sleep(for: .milliseconds(400))
                guard let self else { return }
                await self.repairLayout()
                if !self.hiddenIDs.isEmpty { self.hide() }
            }
        }
    }

    /// Saved positions or a stray drag can break the layout this feature relies on:
    /// [hidden icons] [divider] [chevron] … [Quitter]. Repairs it with at most two drags
    /// (needs Accessibility; revealed layout). Does nothing when the order is already right.
    private func repairLayout() async {
        guard isRevealed, MenuBarScanner.isTrusted, let screen = await activeScreen() else { return }
        func frames() -> (divider: CGRect, toggle: CGRect, own: CGRect?)? {
            guard let divider = cgFrame(of: dividerItem).map({ translate($0, to: screen) }),
                  let toggle = cgFrame(of: toggleItem).map({ translate($0, to: screen) }) else { return nil }
            return (divider, toggle, cgFrame(of: ownItem).map { translate($0, to: screen) })
        }
        if let f = frames(), f.divider.midX > f.toggle.midX {
            await commandDrag(from: CGPoint(x: f.divider.midX, y: f.divider.midY),
                              to: CGPoint(x: f.toggle.minX - 4, y: f.divider.midY))
            try? await Task.sleep(for: .milliseconds(300))
        }
        if let f = frames(), let own = f.own, own.midX < f.divider.maxX {
            await commandDrag(from: CGPoint(x: own.midX, y: own.midY),
                              to: CGPoint(x: f.toggle.maxX + 6, y: own.midY))
            try? await Task.sleep(for: .milliseconds(300))
        }
    }

    // MARK: Enable / disable

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        defaults.set(enabled, forKey: Key.enabled)
        if enabled {
            installItems()
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(400))
                await self?.repairLayout()
            }
        } else {
            reveal()
            removeItems()
        }
    }

    private func installItems() {
        guard toggleItem == nil else { return }
        // A new status item appears left of existing ones, so create the toggle first: the
        // divider then sits to its left. autosaveName keeps both positions across launches.
        let toggle = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        toggle.autosaveName = "QuitterHiderToggle"
        if let button = toggle.button {
            button.target = self
            button.action = #selector(toggleClicked)
            button.toolTip = "Show or hide menu bar icons"
        }
        let divider = NSStatusBar.system.statusItem(withLength: Self.dividerLength)
        divider.autosaveName = "QuitterHiderDivider"
        divider.button?.appearsDisabled = true
        toggleItem = toggle
        dividerItem = divider
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isRevealed else { return }
                self.dividerItem?.length = self.hiddenLength()
            }
        }
        isRevealed = true
        updateImages()
    }

    private func removeItems() {
        autoHideTask?.cancel()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        // Removing a status item forgets its saved position; keep it for next time.
        let saved = ["QuitterHiderToggle", "QuitterHiderDivider"].map {
            ($0, defaults.object(forKey: "NSStatusItem Preferred Position \($0)"))
        }
        if let dividerItem { NSStatusBar.system.removeStatusItem(dividerItem) }
        if let toggleItem { NSStatusBar.system.removeStatusItem(toggleItem) }
        for (name, value) in saved where value != nil {
            defaults.set(value, forKey: "NSStatusItem Preferred Position \(name)")
        }
        dividerItem = nil
        toggleItem = nil
    }

    // MARK: Show / hide

    @objc private func toggleClicked() {
        isRevealed ? hide() : reveal(autoHide: true)
    }

    func hide() {
        guard let dividerItem else { return }
        autoHideTask?.cancel()
        dividerItem.length = hiddenLength()
        isRevealed = false
        updateImages()
    }

    func reveal(autoHide: Bool = false) {
        autoHideTask?.cancel()
        dividerItem?.length = Self.dividerLength
        isRevealed = true
        updateImages()
        guard autoHide, autoHideSeconds > 0, !hiddenIDs.isEmpty else { return }
        let delay = autoHideSeconds
        autoHideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    /// Length that makes the divider reach the left edge of its screen. Too short leaves hidden
    /// icons visible; much longer (≈2× on macOS 27) makes the system drop the divider itself.
    private func hiddenLength() -> CGFloat {
        guard let divider = cgFrame(of: dividerItem), let screen = screenRect(containing: divider) else {
            return 600
        }
        return Self.hiddenLength(dividerMaxX: divider.maxX, screenMinX: screen.minX)
    }

    /// Divider length that spans from the screen's left edge to the divider's right edge.
    nonisolated static func hiddenLength(dividerMaxX: CGFloat, screenMinX: CGFloat) -> CGFloat {
        max(dividerLength, dividerMaxX - screenMinX + 8)
    }

    private func updateImages() {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let chevron = NSImage(
            systemSymbolName: isRevealed ? "chevron.right" : "chevron.left",
            accessibilityDescription: isRevealed ? "Hide menu bar icons" : "Show hidden menu bar icons"
        )?.withSymbolConfiguration(config)
        chevron?.isTemplate = true
        toggleItem?.button?.image = chevron
        let line = isRevealed
            ? NSImage(systemSymbolName: "line.diagonal", accessibilityDescription: "Hidden icons start here")
            : nil
        line?.isTemplate = true
        dividerItem?.button?.image = line
    }

    // MARK: Moving icons

    /// Moves `item` to the hidden side (left of the divider) or back to the visible side.
    /// Returns false when the icon did not end up where it should.
    @discardableResult
    func setHidden(_ hidden: Bool, item: MenuBarItem) async -> Bool {
        guard isEnabled, !isMoving, MenuBarScanner.isTrusted else { return false }
        isMoving = true
        defer { isMoving = false }
        let wasHidden = !isRevealed
        reveal()
        // Give the menu bar a moment to lay the icons out again.
        try? await Task.sleep(for: .milliseconds(350))
        await repairLayout()

        let moved = await drag(itemID: item.id, toHiddenSide: hidden)
        if hidden { hiddenIDs.insert(item.id) } else { hiddenIDs.remove(item.id) }
        defaults.set(Array(hiddenIDs).sorted(), forKey: Key.hiddenIDs)

        if wasHidden && !hiddenIDs.isEmpty { hide() }
        return moved
    }

    private func drag(itemID: String, toHiddenSide hidden: Bool) async -> Bool {
        var neighbours = defaults.dictionary(forKey: Key.neighbours) as? [String: String] ?? [:]
        for attempt in 0..<2 {
            let scanned = await MenuBarScanner.scan()
            guard
                let item = scanned.first(where: { $0.id == itemID }),
                let screen = screenRect(containing: item.frame),
                let divider = cgFrame(of: dividerItem).map({ translate($0, to: screen) }),
                let toggle = cgFrame(of: toggleItem).map({ translate($0, to: screen) })
            else { return false }
            if side(of: item, divider: divider) == hidden { break }
            let target: CGPoint
            if hidden {
                // Remember the visible icon to its right so un-hiding can put it back.
                let right = scanned.first { $0.frame.minX > item.frame.maxX - 1 && $0.frame.minY == item.frame.minY }
                if attempt == 0 { neighbours[itemID] = right?.id }
                target = CGPoint(x: divider.minX - 6, y: item.frame.midY)
            } else if let neighbourID = neighbours[itemID],
                      let neighbour = scanned.first(where: { $0.id == neighbourID }),
                      !side(of: neighbour, divider: divider) {
                // Drop just left of the icon it used to sit beside.
                target = CGPoint(x: neighbour.frame.minX - 3, y: item.frame.midY)
            } else {
                target = CGPoint(x: toggle.maxX + 6, y: item.frame.midY)
            }
            await commandDrag(from: CGPoint(x: item.frame.midX, y: item.frame.midY), to: target)
            try? await Task.sleep(for: .milliseconds(250 + attempt * 250))
        }
        if !hidden { neighbours[itemID] = nil }
        defaults.set(neighbours, forKey: Key.neighbours)
        guard let item = await MenuBarScanner.scan().first(where: { $0.id == itemID }),
              let screen = screenRect(containing: item.frame),
              let divider = cgFrame(of: dividerItem).map({ translate($0, to: screen) }) else { return false }
        return side(of: item, divider: divider) == hidden
    }

    /// True when the icon sits left of the divider (on the hidden side). Both on one display.
    func side(of item: MenuBarItem, divider: CGRect) -> Bool {
        item.frame.midX < divider.midX
    }

    /// The display whose menu bar Accessibility currently reports (the one in use).
    private func activeScreen() async -> CGRect? {
        guard let item = await MenuBarScanner.scan().first else { return nil }
        return screenRect(containing: item.frame)
    }

    /// Our status item windows can sit on another display's menu bar. Icons are right-aligned on
    /// every display, so move a frame onto `screen` by matching right and top edges.
    private func translate(_ rect: CGRect, to screen: CGRect) -> CGRect {
        guard let source = screenRect(containing: rect) else { return rect }
        return Self.translate(rect, from: source, to: screen)
    }

    nonisolated static func translate(_ rect: CGRect, from source: CGRect, to screen: CGRect) -> CGRect {
        rect.offsetBy(dx: screen.maxX - source.maxX, dy: screen.minY - source.minY)
    }

    /// ⌘-drags the icon at `from` to `to` (global top-left coordinates), then puts the cursor back.
    /// The pause over the drop point lets the menu bar settle the insertion position.
    private func commandDrag(from: CGPoint, to: CGPoint) async {
        let source = CGEventSource(stateID: .combinedSessionState)
        let original = CGEvent(source: nil)?.location ?? from
        func post(_ type: CGEventType, _ point: CGPoint) {
            let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
        post(.mouseMoved, from)
        try? await Task.sleep(for: .milliseconds(30))
        post(.leftMouseDown, from)
        try? await Task.sleep(for: .milliseconds(60))
        let steps = 24
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            post(.leftMouseDragged, CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t))
            try? await Task.sleep(for: .milliseconds(20))
        }
        for _ in 0..<6 {
            post(.leftMouseDragged, to)
            try? await Task.sleep(for: .milliseconds(50))
        }
        post(.leftMouseUp, to)
        try? await Task.sleep(for: .milliseconds(30))
        CGWarpMouseCursorPosition(original)
    }

    // MARK: Geometry (global, top-left origin)

    private func cgFrame(of item: NSStatusItem?) -> CGRect? {
        guard let window = item?.button?.window else { return nil }
        return Self.toCG(window.frame)
    }

    private func screenRect(containing rect: CGRect) -> CGRect? {
        let point = CGPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens.map { Self.toCG($0.frame) }.first { $0.contains(point) }
    }

    private static func toCG(_ rect: NSRect) -> CGRect {
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: rect.minX, y: mainHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}

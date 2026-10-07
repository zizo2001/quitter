import AppKit
import ApplicationServices

/// One icon on the right-hand side of the menu bar, owned by some app's extras menu bar.
struct MenuBarItem: Identifiable, Hashable, Sendable {
    /// Stable across launches: owning bundle ID plus the item's AX identifier, title or index.
    let id: String
    let pid: pid_t
    let bundleID: String?
    let appName: String
    let title: String
    /// Global screen coordinates, top-left origin (the space CGEvent locations use). Reported for
    /// the menu bar of the display macOS considers active.
    let frame: CGRect
}

/// Reads menu bar extras through the Accessibility API. No Screen Recording and no polling: it
/// runs only when asked (Settings open, applying a change), one short query per app in parallel.
enum MenuBarScanner {
    /// Processes whose items are managed in System Settings › Menu Bar, not by Quitter.
    static let systemOwners: Set<String> = ["com.apple.MenuBarAgent", "com.apple.controlcenter", "com.apple.systemuiserver"]

    private struct Target: Sendable {
        let pid: pid_t
        let bundleID: String?
        let name: String
    }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that leads to Privacy & Security › Accessibility.
    static func requestTrust() {
        // Literal value of kAXTrustedCheckOptionPrompt (the global is not concurrency-safe in Swift 6).
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// Every third-party menu bar item, left to right.
    static func scan() async -> [MenuBarItem] {
        guard isTrusted else { return [] }
        let targets = await MainActor.run { () -> [Target] in
            let own = ProcessInfo.processInfo.processIdentifier
            return NSWorkspace.shared.runningApplications.compactMap { app in
                // Never query ourselves: the reply needs our main thread.
                guard app.processIdentifier != own, !app.isTerminated else { return nil }
                if let id = app.bundleIdentifier, systemOwners.contains(id) { return nil }
                return Target(
                    pid: app.processIdentifier,
                    bundleID: app.bundleIdentifier,
                    name: app.localizedName ?? app.bundleIdentifier ?? "PID \(app.processIdentifier)"
                )
            }
        }
        let items = await withTaskGroup(of: [MenuBarItem].self) { group in
            for target in targets {
                group.addTask { extras(of: target) }
            }
            var all: [MenuBarItem] = []
            for await batch in group { all.append(contentsOf: batch) }
            return all
        }
        return items.sorted { $0.frame.minX < $1.frame.minX }
    }

    /// Right edge (global x) of the frontmost app's menus: where the menu bar's free space begins.
    static func appMenusMaxX() -> CGFloat? {
        guard isTrusted, let front = NSWorkspace.shared.frontmostApplication else { return nil }
        let element = AXUIElementCreateApplication(front.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.25)
        guard
            let bar: AXUIElement = attribute(element, kAXMenuBarAttribute),
            let menus: [AXUIElement] = attribute(bar, kAXChildrenAttribute)
        else { return nil }
        return menus.compactMap(frame(of:)).map(\.maxX).max()
    }

    private static func extras(of target: Target) -> [MenuBarItem] {
        let element = AXUIElementCreateApplication(target.pid)
        AXUIElementSetMessagingTimeout(element, 0.25)
        guard
            let bar: AXUIElement = attribute(element, "AXExtrasMenuBar"),
            let children: [AXUIElement] = attribute(bar, kAXChildrenAttribute)
        else { return [] }
        return children.enumerated().compactMap { index, child in
            // Items whose frame is below the menu bar are open menus or popovers, not icons.
            guard let frame = frame(of: child), frame.height <= 40 else { return nil }
            let identifier: String? = attribute(child, kAXIdentifierAttribute)
            let title: String = attribute(child, kAXTitleAttribute)
                ?? attribute(child, kAXDescriptionAttribute)
                ?? ""
            let key = identifier ?? (title.isEmpty ? "#\(index)" : title)
            return MenuBarItem(
                id: "\(target.bundleID ?? target.name)|\(key)",
                pid: target.pid,
                bundleID: target.bundleID,
                appName: target.name,
                title: title,
                frame: frame
            )
        }
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard
            let positionValue: AXValue = attribute(element, kAXPositionAttribute),
            let sizeValue: AXValue = attribute(element, kAXSizeAttribute)
        else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &origin),
              AXValueGetValue(sizeValue, .cgSize, &size) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}

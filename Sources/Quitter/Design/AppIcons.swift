import AppKit

/// Icons and names for apps that may not be running, resolved through LaunchServices.
@MainActor
enum AppIcons {
    private static var cache: [String: NSImage] = [:]

    /// Quitter's own icon, drawn at a fixed size through the same LaunchServices path Finder uses,
    /// so the About pane and Protected list match what the Dock and Finder show.
    static func ownIcon(size: CGFloat) -> NSImage {
        let source = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        return NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            source.draw(in: rect)
            return true
        }
    }

    static func url(forBundleID bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    static func icon(forBundleID bundleID: String) -> NSImage {
        if let cached = cache[bundleID] { return cached }
        if bundleID == ProtectedStore.selfBundleID, Bundle.main.bundleIdentifier == bundleID {
            return ownIcon(size: 64)
        }
        let image = url(forBundleID: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSWorkspace.shared.icon(for: .application)
        cache[bundleID] = image
        return image
    }

    static func name(forBundleID bundleID: String) -> String? {
        url(forBundleID: bundleID).map(displayName(of:))
    }

    static func displayName(of url: URL) -> String {
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    /// Bundle ID and name of a user-chosen `.app`.
    static func appInfo(at url: URL) -> (bundleID: String, name: String)? {
        guard let bundleID = Bundle(url: url)?.bundleIdentifier else { return nil }
        return (bundleID, displayName(of: url))
    }
}

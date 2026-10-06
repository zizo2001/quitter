import Foundation
import Observation

/// Apps that never appear in the panel. Quitter itself is always protected; Finder is seeded
/// on first launch and can be removed.
@MainActor
@Observable
final class ProtectedStore {
    static let selfBundleID = "com.azizali.quitter"
    static let finderBundleID = "com.apple.finder"

    private(set) var apps: [ProtectedApp] = []
    @ObservationIgnored private let file: JSONFileStore<[ProtectedApp]>

    /// Always contains Quitter's own bundle ID.
    var bundleIDs: Set<String> {
        Set(apps.map(\.bundleID)).union([Self.selfBundleID])
    }

    init(directory: URL = JSONFileStore<[ProtectedApp]>.defaultDirectory) {
        file = JSONFileStore(url: directory.appendingPathComponent("protected.json"))
        switch file.load() {
        case .loaded(let stored):
            apps = stored
        case .missing:
            apps = [ProtectedApp(bundleID: Self.finderBundleID, name: "Finder")]
            persist()
        case .corrupt:
            apps = []
        }
        ensureSelf()
    }

    func isRemovable(_ bundleID: String) -> Bool {
        bundleID != Self.selfBundleID
    }

    func add(_ app: ProtectedApp) {
        guard !apps.contains(where: { $0.bundleID == app.bundleID }) else { return }
        apps.append(app)
        persist()
    }

    func remove(bundleID: String) {
        guard isRemovable(bundleID) else { return }
        apps.removeAll { $0.bundleID == bundleID }
        persist()
    }

    private func ensureSelf() {
        guard !apps.contains(where: { $0.bundleID == Self.selfBundleID }) else { return }
        apps.insert(ProtectedApp(bundleID: Self.selfBundleID, name: "Quitter"), at: 0)
        persist()
    }

    private func persist() {
        do {
            try file.save(apps)
        } catch {
            NSLog("Quitter: could not save protected.json: \(error)")
        }
    }
}

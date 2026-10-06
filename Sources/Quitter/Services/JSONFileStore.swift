import Foundation

/// Atomic JSON persistence for one Codable value. A file that fails to decode is renamed to
/// `<name>.corrupt-<timestamp>` and reported as missing, so bad JSON never crashes the app.
struct JSONFileStore<Value: Codable> {
    enum LoadResult {
        case missing
        case loaded(Value)
        /// Decode failed; the bad file was moved to `movedTo`.
        case corrupt(movedTo: URL?)
    }

    let url: URL

    /// `~/Library/Application Support/Quitter/`
    static var defaultDirectory: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Quitter", isDirectory: true)
    }

    func load() -> LoadResult {
        guard let data = try? Data(contentsOf: url) else { return .missing }
        do {
            return .loaded(try JSONDecoder().decode(Value.self, from: data))
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let aside = url.appendingPathExtension("corrupt-\(stamp)")
            let moved = (try? FileManager.default.moveItem(at: url, to: aside)) != nil
            NSLog("Quitter: \(url.lastPathComponent) is corrupt (\(error)); moved aside")
            return .corrupt(movedTo: moved ? aside : nil)
        }
    }

    func save(_ value: Value) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}

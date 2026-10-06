import Foundation

struct QuitGroup: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    /// SF Symbol name.
    var symbol: String
    /// Order preserved.
    var bundleIDs: [String]

    init(id: UUID = UUID(), name: String, symbol: String = "square.stack", bundleIDs: [String]) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.bundleIDs = bundleIDs
    }
}

struct ProtectedApp: Codable, Hashable, Sendable {
    let bundleID: String
    let name: String
}

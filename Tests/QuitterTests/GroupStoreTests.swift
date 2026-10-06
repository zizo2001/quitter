import Foundation
import Testing
@testable import Quitter

@MainActor
struct GroupStoreTests {
    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    @Test func roundTripsThroughDisk() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = GroupStore(directory: dir)
        #expect(store.groups.isEmpty)
        let focus = QuitGroup(name: "Focus", symbol: "moon", bundleIDs: ["com.apple.Safari", "com.apple.Notes"])
        store.upsert(focus)

        let reloaded = GroupStore(directory: dir)
        #expect(reloaded.groups == [focus])
        let json = try String(contentsOf: dir.appendingPathComponent("groups.json"), encoding: .utf8)
        #expect(json.contains("\"name\" : \"Focus\""))
    }

    @Test func upsertReplacesByIDAndKeepsAppOrder() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = GroupStore(directory: dir)
        var group = QuitGroup(name: "A", bundleIDs: ["b", "a"])
        store.upsert(group)
        group.name = "Renamed"
        group.bundleIDs = ["c", "b", "a"]
        store.upsert(group)
        #expect(store.groups.count == 1)
        #expect(store.groups[0].name == "Renamed")
        #expect(store.groups[0].bundleIDs == ["c", "b", "a"])
    }

    @Test func removeAndMovePersist() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = GroupStore(directory: dir)
        let a = QuitGroup(name: "A", bundleIDs: [])
        let b = QuitGroup(name: "B", bundleIDs: [])
        let c = QuitGroup(name: "C", bundleIDs: [])
        [a, b, c].forEach(store.upsert)
        store.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        store.remove(id: b.id)
        #expect(GroupStore(directory: dir).groups.map(\.name) == ["C", "A"])
    }

    @Test func corruptFileStartsEmptyAndIsMovedAside() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("[{\"broken\": ".utf8).write(to: dir.appendingPathComponent("groups.json"))
        let store = GroupStore(directory: dir)
        #expect(store.groups.isEmpty)
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(names.contains { $0.hasPrefix("groups.json.corrupt-") })
    }
}

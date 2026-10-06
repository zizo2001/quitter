import AppKit
import Foundation
import Testing
@testable import Quitter

@MainActor
private func app(
    _ pid: pid_t,
    _ name: String,
    bundle: String? = nil,
    memory: UInt64? = nil,
    cpu: Double? = nil,
    launched: TimeInterval? = nil
) -> RunningApp {
    let usage: Usage? = memory.map {
        Usage(memoryBytes: $0, cpuPercent: cpu ?? 0, isFirstSample: false)
    }
    return RunningApp(
        id: pid,
        bundleID: bundle ?? "test.\(name.lowercased())",
        name: name,
        icon: NSImage(),
        launchDate: launched.map(Date.init(timeIntervalSince1970:)),
        policy: .regular,
        usage: usage
    )
}

@MainActor
struct AppFilterTests {
    @Test func protectedAppsNeverAppear() {
        let apps = [app(1, "Finder", bundle: "com.apple.finder"), app(2, "Safari")]
        let result = AppFilter.apply(apps: apps, protected: ["com.apple.finder"], query: "", sort: .name)
        #expect(result.map(\.name) == ["Safari"])
    }

    @Test func queryIsCaseAndDiacriticInsensitiveContains() {
        let apps = [app(1, "TextEdit"), app(2, "Calculator"), app(3, "Café Notes")]
        #expect(AppFilter.apply(apps: apps, protected: [], query: "text", sort: .name).map(\.id) == [1])
        #expect(AppFilter.apply(apps: apps, protected: [], query: "EDIT", sort: .name).map(\.id) == [1])
        #expect(AppFilter.apply(apps: apps, protected: [], query: "cafe", sort: .name).map(\.id) == [3])
        #expect(AppFilter.apply(apps: apps, protected: [], query: "  calc ", sort: .name).map(\.id) == [2])
        #expect(AppFilter.apply(apps: apps, protected: [], query: "xyz", sort: .name).isEmpty)
    }

    @Test func nameSortIsLocalizedCaseInsensitive() {
        let apps = [app(1, "zed"), app(2, "Alpha"), app(3, "beta")]
        #expect(AppFilter.apply(apps: apps, protected: [], query: "", sort: .name).map(\.name) == ["Alpha", "beta", "zed"])
    }

    @Test func memorySortDescendingWithNilLast() {
        let apps = [app(1, "A"), app(2, "B", memory: 100), app(3, "C", memory: 300)]
        #expect(AppFilter.apply(apps: apps, protected: [], query: "", sort: .memory).map(\.id) == [3, 2, 1])
    }

    @Test func cpuSortDescendingWithNilLast() {
        let apps = [app(1, "A", memory: 1, cpu: 5), app(2, "B"), app(3, "C", memory: 1, cpu: 150)]
        #expect(AppFilter.apply(apps: apps, protected: [], query: "", sort: .cpu).map(\.id) == [3, 1, 2])
    }

    @Test func launchedSortNewestFirstWithNilLast() {
        let apps = [app(1, "A", launched: 100), app(2, "B"), app(3, "C", launched: 200)]
        #expect(AppFilter.apply(apps: apps, protected: [], query: "", sort: .launched).map(\.id) == [3, 1, 2])
    }

    @Test func tiesFallBackToName() {
        let apps = [app(1, "Zeta", memory: 10), app(2, "Alpha", memory: 10)]
        #expect(AppFilter.apply(apps: apps, protected: [], query: "", sort: .memory).map(\.name) == ["Alpha", "Zeta"])
    }
}

@MainActor
struct ProtectedStoreTests {
    @Test func seedsFinderAndAlwaysContainsSelf() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ProtectedStore(directory: dir)
        #expect(store.bundleIDs.contains("com.apple.finder"))
        #expect(store.bundleIDs.contains(ProtectedStore.selfBundleID))
        store.remove(bundleID: ProtectedStore.selfBundleID)
        #expect(store.bundleIDs.contains(ProtectedStore.selfBundleID))
        store.remove(bundleID: "com.apple.finder")
        let reloaded = ProtectedStore(directory: dir)
        #expect(!reloaded.bundleIDs.contains("com.apple.finder"))
        #expect(reloaded.bundleIDs.contains(ProtectedStore.selfBundleID))
    }

    @Test func corruptFileIsMovedAsideNotFatal() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{not json".utf8).write(to: dir.appendingPathComponent("protected.json"))
        let store = ProtectedStore(directory: dir)
        #expect(store.apps.map(\.bundleID) == [ProtectedStore.selfBundleID])
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(names.contains { $0.hasPrefix("protected.json.corrupt-") })
    }
}

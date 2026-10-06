import Foundation
import Observation

/// Quit Groups persisted to `groups.json`. Order is the user's order.
@MainActor
@Observable
final class GroupStore {
    private(set) var groups: [QuitGroup] = []
    @ObservationIgnored private let file: JSONFileStore<[QuitGroup]>

    init(directory: URL = JSONFileStore<[QuitGroup]>.defaultDirectory) {
        file = JSONFileStore(url: directory.appendingPathComponent("groups.json"))
        if case .loaded(let stored) = file.load() {
            groups = stored
        }
    }

    func group(id: UUID) -> QuitGroup? {
        groups.first { $0.id == id }
    }

    /// Inserts a new group or replaces the one with the same id.
    func upsert(_ group: QuitGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
        } else {
            groups.append(group)
        }
        persist()
    }

    func remove(id: UUID) {
        groups.removeAll { $0.id == id }
        persist()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        groups.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    private func persist() {
        do {
            try file.save(groups)
        } catch {
            NSLog("Quitter: could not save groups.json: \(error)")
        }
    }
}

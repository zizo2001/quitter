import Foundation

/// Pure list shaping: protected removal, search, sort (PLAN §6).
enum AppFilter {
    static func apply(
        apps: [RunningApp],
        protected: Set<String>,
        query: String,
        sort: SortOrder
    ) -> [RunningApp] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let visible = apps.filter { app in
            if let bundleID = app.bundleID, protected.contains(bundleID) { return false }
            return trimmed.isEmpty || matches(name: app.name, query: trimmed)
        }
        return sorted(visible, by: sort)
    }

    /// Case- and diacritic-insensitive prefix-or-contains match.
    static func matches(name: String, query: String) -> Bool {
        name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    static func sorted(_ apps: [RunningApp], by order: SortOrder) -> [RunningApp] {
        apps.sorted { lhs, rhs in
            switch order {
            case .name:
                break
            case .memory:
                if let result = descending(lhs.usage?.memoryBytes, rhs.usage?.memoryBytes) { return result }
            case .cpu:
                if let result = descending(lhs.usage?.cpuPercent, rhs.usage?.cpuPercent) { return result }
            case .launched:
                if let result = descending(lhs.launchDate, rhs.launchDate) { return result }
            }
            return byName(lhs, rhs)
        }
    }

    /// Larger first, nil last. Returns nil when the two are equal (caller breaks the tie).
    private static func descending<T: Comparable>(_ lhs: T?, _ rhs: T?) -> Bool? {
        switch (lhs, rhs) {
        case let (l?, r?): l == r ? nil : l > r
        case (.some, nil): true
        case (nil, .some): false
        case (nil, nil): nil
        }
    }

    private static func byName(_ lhs: RunningApp, _ rhs: RunningApp) -> Bool {
        let result = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        return result == .orderedSame ? lhs.id < rhs.id : result == .orderedAscending
    }
}

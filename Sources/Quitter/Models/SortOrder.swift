enum SortOrder: String, CaseIterable, Identifiable, Sendable {
    case name, memory, cpu, launched

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: "Name"
        case .memory: "Memory"
        case .cpu: "CPU"
        case .launched: "Launched"
        }
    }
}

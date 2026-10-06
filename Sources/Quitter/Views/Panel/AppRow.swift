import SwiftUI

struct AppRow: View {
    let app: RunningApp
    let isSelected: Bool
    let isHighlighted: Bool
    let showUsage: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Spacing.m) {
            Toggle("", isOn: Binding(get: { isSelected }, set: { _ in onToggle() }))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .accessibilityLabel(accessibilityLabel)
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: Tokens.Size.icon, height: Tokens.Size.icon)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if showUsage {
                    Text(UsageFormat.subtitle(app.usage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .help("Includes helper processes")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Tokens.Spacing.s)
        .frame(height: Tokens.Size.row)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: Tokens.Radius.row, style: .continuous)
                    .fill(.quaternary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }

    private var accessibilityLabel: String {
        guard showUsage, let usage = app.usage else { return "Quit \(app.name)" }
        return "Quit \(app.name), \(UsageFormat.memory(usage.memoryBytes))"
    }
}

enum UsageFormat {
    static func memory(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: bytes), countStyle: .memory)
    }

    static func cpu(_ usage: Usage) -> String {
        usage.isFirstSample ? "—" : "\(Int(usage.cpuPercent.rounded())) %"
    }

    static func subtitle(_ usage: Usage?) -> String {
        guard let usage else { return "—" }
        return "\(memory(usage.memoryBytes)) · \(cpu(usage))"
    }
}

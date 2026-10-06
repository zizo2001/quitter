import SwiftUI

struct AppRow: View {
    let app: RunningApp
    let state: QuitState
    let isSelected: Bool
    let isHighlighted: Bool
    let showUsage: Bool
    let onToggle: () -> Void
    let onForceQuit: () -> Void

    private var isRequested: Bool {
        if case .requested = state { return true }
        return false
    }

    var body: some View {
        HStack(spacing: Tokens.Spacing.m) {
            Toggle("", isOn: Binding(get: { isSelected }, set: { _ in onToggle() }))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(state.isPending)
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
            trailing
        }
        .padding(.horizontal, Tokens.Spacing.s)
        .frame(height: Tokens.Size.row)
        .opacity(isRequested ? 0.5 : 1)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: Tokens.Radius.row, style: .continuous)
                    .fill(.quaternary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }

    @ViewBuilder
    private var trailing: some View {
        switch state {
        case .requested:
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Quitting \(app.name)")
        case .stuck:
            Button("Force Quit", action: onForceQuit)
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
                .accessibilityLabel("Force Quit \(app.name)")
        case .idle, .terminated:
            EmptyView()
        }
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

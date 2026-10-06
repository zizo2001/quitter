import SwiftUI

struct PanelFooter: View {
    let selectedCount: Int
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Text("\(selectedCount) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(selectedCount == 0 ? "Quit" : "Quit \(selectedCount)", action: onQuit)
                    .buttonStyle(.glassProminent)
                    .tint(.red)
                    .disabled(selectedCount == 0)
                    .accessibilityLabel(selectedCount == 0 ? "Quit" : "Quit \(selectedCount) apps")
            }
            .padding(.horizontal, Tokens.Spacing.l)
            .frame(maxHeight: .infinity)
        }
        .frame(height: Tokens.Size.footer)
    }
}

/// In-panel confirmation shown instead of quitting when "Ask before quitting" is on.
struct ConfirmQuitOverlay: View {
    let apps: [RunningApp]
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.25))
                .onTapGesture(perform: onCancel)
            VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
                Text(apps.count == 1 ? "Quit 1 app?" : "Quit \(apps.count) apps?")
                    .font(.headline)
                Text(apps.map(\.name).formatted(.list(type: .and)))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                HStack {
                    Spacer()
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.glass)
                    Button("Quit", action: onConfirm)
                        .buttonStyle(.glassProminent)
                        .tint(.red)
                }
                .padding(.top, Tokens.Spacing.xs)
            }
            .padding(Tokens.Spacing.l)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Tokens.Radius.field, style: .continuous))
            .padding(Tokens.Spacing.s)
        }
    }
}

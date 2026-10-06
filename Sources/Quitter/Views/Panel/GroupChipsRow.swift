import SwiftUI

/// Horizontal capsules, one per Quit Group: "Focus · 3". Click selects the group's running
/// members; click again deselects them. Dimmed and disabled when none are running.
struct GroupChipsRow: View {
    let chips: [PanelModel.Chip]
    let onToggle: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: Tokens.Spacing.s) {
                HStack(spacing: Tokens.Spacing.s) {
                    ForEach(chips) { chip in
                        ChipButton(chip: chip) { onToggle(chip.id) }
                    }
                }
                .padding(.horizontal, Tokens.Spacing.m)
            }
        }
        .scrollIndicators(.never)
        .frame(height: Tokens.Size.chips)
    }
}

private struct ChipButton: View {
    let chip: PanelModel.Chip
    let action: () -> Void

    private var isEnabled: Bool { !chip.pids.isEmpty }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.xs) {
                Image(systemName: chip.group.symbol)
                Text("\(chip.group.name) · \(chip.pids.count)")
                    .lineLimit(1)
            }
            .font(.callout)
            .padding(.horizontal, Tokens.Spacing.m)
            .padding(.vertical, 6)
            .foregroundStyle(chip.isFullySelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .glassEffect(
            chip.isFullySelected ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
            in: .capsule
        )
        .opacity(isEnabled ? 1 : 0.4)
        .disabled(!isEnabled)
        .accessibilityLabel("\(chip.group.name), \(chip.pids.count) running")
        .accessibilityValue(chip.isFullySelected ? "Selected" : "")
    }
}

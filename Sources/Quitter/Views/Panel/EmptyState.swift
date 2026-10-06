import SwiftUI

struct EmptyState: View {
    let title: String
    let caption: String?

    static let height: CGFloat = 160

    var body: some View {
        VStack(spacing: Tokens.Spacing.s) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Tokens.Spacing.l)
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .accessibilityElement(children: .combine)
    }
}

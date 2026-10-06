import SwiftUI

struct SearchField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: Tokens.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search apps", text: $text)
                .textFieldStyle(.plain)
                .focused(isFocused)
                .accessibilityLabel("Search apps")
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Tokens.Spacing.m - 2)
        .frame(height: Tokens.Size.search)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: Tokens.Radius.field, style: .continuous))
    }
}

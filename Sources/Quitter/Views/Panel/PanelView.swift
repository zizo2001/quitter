import SwiftUI

struct PanelView: View {
    let onHeightChange: (CGFloat) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Quitter").font(.headline)
                Spacer()
            }
            .padding(.horizontal, Tokens.Spacing.l)
            .frame(height: Tokens.Size.header)
            Spacer().frame(height: 160)
        }
        .frame(width: Tokens.Size.panelWidth)
        .panelBackground()
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeightChange($0) }
    }
}

import SwiftUI

extension View {
    /// Liquid Glass background for the panel root (PLAN §7).
    func panelBackground() -> some View {
        glassEffect(.regular, in: RoundedRectangle(cornerRadius: Tokens.Radius.panel, style: .continuous))
    }
}

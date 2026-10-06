import SwiftUI

/// Panel root. Every section has a fixed height so the panel's ideal height is deterministic;
/// the measured height is reported to the window, which keeps its top edge anchored.
struct PanelView: View {
    @Bindable var model: PanelModel
    let onHeightChange: (CGFloat) -> Void
    @FocusState private var searchFocused: Bool

    private static let searchBlock = Tokens.Size.search + Tokens.Spacing.s

    var body: some View {
        let apps = model.visibleApps
        VStack(spacing: 0) {
            header
            SearchField(text: $model.query, isFocused: $searchFocused)
                .padding(.horizontal, Tokens.Spacing.m)
                .padding(.bottom, Tokens.Spacing.s)
            if apps.isEmpty {
                EmptyState(title: model.emptyMessage.title, caption: model.emptyMessage.caption)
            } else {
                list(apps)
            }
        }
        .frame(width: Tokens.Size.panelWidth)
        .panelBackground()
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeightChange($0) }
        .onChange(of: model.focusRequest, initial: true) { searchFocused = true }
        .onChange(of: searchFocused, initial: true) { model.isSearchFocused = searchFocused }
    }

    private var header: some View {
        HStack {
            Text("Quitter").font(.headline)
            Spacer()
        }
        .padding(.horizontal, Tokens.Spacing.l)
        .frame(height: Tokens.Size.header)
    }

    private var chromeHeight: CGFloat {
        Tokens.Size.header + Self.searchBlock
    }

    private func list(_ apps: [RunningApp]) -> some View {
        let content = CGFloat(apps.count) * Tokens.Size.row + Tokens.Spacing.s
        let maxList = Tokens.Size.panelMaxHeight - chromeHeight
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(apps) { app in
                        AppRow(
                            app: app,
                            isSelected: model.selection.contains(app.id),
                            isHighlighted: model.cursor == app.id,
                            showUsage: model.settings.showUsage,
                            onToggle: { model.toggle(app.id) }
                        )
                        .id(app.id)
                    }
                }
                .padding(.horizontal, Tokens.Size.listInset)
                .padding(.bottom, Tokens.Spacing.s)
            }
            .scrollIndicators(.automatic)
            .frame(height: min(content, maxList))
            .onChange(of: model.cursor) { _, cursor in
                if let cursor { proxy.scrollTo(cursor) }
            }
        }
    }
}

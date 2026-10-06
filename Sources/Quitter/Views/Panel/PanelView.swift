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
        let chips = model.chips
        VStack(spacing: 0) {
            header
            SearchField(text: $model.query, isFocused: $searchFocused)
                .padding(.horizontal, Tokens.Spacing.m)
                .padding(.bottom, Tokens.Spacing.s)
            if !chips.isEmpty {
                GroupChipsRow(chips: chips, onToggle: model.toggleGroup)
                    .padding(.bottom, Tokens.Spacing.s)
            }
            if apps.isEmpty {
                EmptyState(title: model.emptyMessage.title, caption: model.emptyMessage.caption)
            } else {
                list(apps, hasChips: !chips.isEmpty)
            }
            PanelFooter(selectedCount: model.quitTargets.count, onQuit: model.requestQuit)
        }
        .frame(width: Tokens.Size.panelWidth)
        .overlay {
            if let confirming = model.confirming {
                ConfirmQuitOverlay(
                    apps: confirming,
                    onCancel: model.cancelConfirmation,
                    onConfirm: model.confirmQuit
                )
            }
        }
        .panelBackground()
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeightChange($0) }
        .onChange(of: model.focusRequest, initial: true) { searchFocused = true }
        .onChange(of: searchFocused, initial: true) { model.isSearchFocused = searchFocused }
    }

    private var header: some View {
        HStack(spacing: Tokens.Spacing.s) {
            Text("Quitter").font(.headline)
            Spacer()
            Button(action: model.onOpenSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
            .accessibilityLabel("Settings")
            Menu {
                // Inline, not a submenu: submenus do not track reliably in a menu opened
                // from a non-activating panel while another app is active.
                Picker("Sort by", selection: Binding(get: { model.settings.sortOrder }, set: { model.setSortOrder($0) })) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
                .pickerStyle(.inline)
                Divider()
                Button("Save selection as Group…", action: model.saveSelectionAsGroup)
                    .disabled(model.selection.isEmpty)
                Divider()
                Button("Select All", action: model.selectAllVisible)
                Button("Select None", action: model.selectNone)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("More")
        }
        .padding(.horizontal, Tokens.Spacing.l)
        .frame(height: Tokens.Size.header)
    }

    private func chromeHeight(hasChips: Bool) -> CGFloat {
        let chips = hasChips ? Tokens.Size.chips + Tokens.Spacing.s : 0
        return Tokens.Size.header + Self.searchBlock + chips + Tokens.Size.footer
    }

    private func list(_ apps: [RunningApp], hasChips: Bool) -> some View {
        let content = CGFloat(apps.count) * Tokens.Size.row + Tokens.Spacing.s
        let maxList = Tokens.Size.panelMaxHeight - chromeHeight(hasChips: hasChips)
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(apps) { app in
                        AppRow(
                            app: app,
                            state: model.coordinator.state(for: app.id),
                            isSelected: model.selection.contains(app.id),
                            isHighlighted: model.cursor == app.id,
                            showUsage: model.settings.showUsage,
                            onToggle: { model.toggle(app.id) },
                            onForceQuit: { model.forceQuit(app.id) }
                        )
                        .id(app.id)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, Tokens.Size.listInset)
                .padding(.bottom, Tokens.Spacing.s)
                .animation(.smooth(duration: Tokens.Motion.rowExit), value: apps.map(\.id))
            }
            .scrollIndicators(.automatic)
            .frame(height: min(content, maxList))
            .onChange(of: model.cursor) { _, cursor in
                if let cursor { proxy.scrollTo(cursor) }
            }
        }
    }
}

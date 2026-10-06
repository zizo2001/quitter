import SwiftUI

struct GroupsPane: View {
    let store: GroupStore
    let monitor: AppMonitor
    @Bindable var navigation: SettingsNavigation
    @State private var selection: UUID?

    var body: some View {
        Form {
            Section {
                List(selection: $selection) {
                    ForEach(store.groups) { group in
                        GroupRow(group: group)
                            .tag(group.id)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { navigation.editingGroup = group }
                            .simultaneousGesture(TapGesture().onEnded { selection = group.id })
                    }
                    .onMove(perform: store.move)
                }
                .frame(minHeight: 200)
                .overlay {
                    if store.groups.isEmpty {
                        Text("No groups yet. Click + to create one.")
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: Tokens.Spacing.s) {
                    Button {
                        navigation.editingGroup = QuitGroup(name: "", bundleIDs: [])
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New group")
                    Button {
                        if let selection { store.remove(id: selection) }
                        selection = nil
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(selection == nil)
                    .accessibilityLabel("Delete group")
                    Spacer()
                    Button("Edit") {
                        if let selection, let group = store.group(id: selection) {
                            navigation.editingGroup = group
                        }
                    }
                    .disabled(selection == nil)
                }
                .buttonStyle(.borderless)
            } footer: {
                Text("Click a group's chip in the panel to select its running apps. Drag to reorder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(item: $navigation.editingGroup) { group in
            GroupEditor(
                group: group,
                runningApps: monitor.apps,
                onSave: { saved in
                    store.upsert(saved)
                    selection = saved.id
                    navigation.editingGroup = nil
                },
                onCancel: { navigation.editingGroup = nil }
            )
        }
    }
}

private struct GroupRow: View {
    let group: QuitGroup

    var body: some View {
        HStack(spacing: Tokens.Spacing.s) {
            Image(systemName: group.symbol)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(group.name)
            Spacer()
            Text(group.bundleIDs.count == 1 ? "1 app" : "\(group.bundleIDs.count) apps")
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

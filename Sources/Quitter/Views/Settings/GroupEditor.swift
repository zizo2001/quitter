import AppKit
import SwiftUI

/// Sheet for creating or editing one Quit Group.
struct GroupEditor: View {
    static let symbols = [
        "square.stack", "moon", "briefcase", "hammer", "paintbrush", "gamecontroller",
        "music.note", "film", "book", "message", "globe", "chevron.left.forwardslash.chevron.right",
    ]

    @State private var draft: QuitGroup
    let runningApps: [RunningApp]
    let onSave: (QuitGroup) -> Void
    let onCancel: () -> Void
    @State private var showingRunning = false

    init(group: QuitGroup, runningApps: [RunningApp], onSave: @escaping (QuitGroup) -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: group)
        self.runningApps = runningApps
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
            Text(draft.name.isEmpty ? "New Group" : draft.name)
                .font(.headline)
            TextField("Name", text: $draft.name, prompt: Text("Group name"))
                .textFieldStyle(.roundedBorder)
            symbolPicker
            appList
            HStack {
                Menu("Add Apps") {
                    Button("Add from running…") { showingRunning = true }
                    Button("Add from disk…", action: addFromDisk)
                }
                .fixedSize()
                .popover(isPresented: $showingRunning, arrowEdge: .bottom) {
                    RunningAppChecklist(apps: runningApps, selected: Set(draft.bundleIDs)) { bundleID, include in
                        if include {
                            if !draft.bundleIDs.contains(bundleID) { draft.bundleIDs.append(bundleID) }
                        } else {
                            draft.bundleIDs.removeAll { $0 == bundleID }
                        }
                    }
                }
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    var saved = draft
                    saved.name = trimmedName
                    onSave(saved)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedName.isEmpty)
            }
        }
        .padding(Tokens.Spacing.xl)
        .frame(width: 420)
    }

    private var symbolPicker: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            ForEach(Self.symbols, id: \.self) { symbol in
                Button {
                    draft.symbol = symbol
                } label: {
                    Image(systemName: symbol)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(draft.symbol == symbol ? Color.accentColor.opacity(0.3) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(symbol)
                .accessibilityAddTraits(draft.symbol == symbol ? .isSelected : [])
            }
        }
    }

    private var appList: some View {
        List {
            ForEach(draft.bundleIDs, id: \.self) { bundleID in
                HStack(spacing: Tokens.Spacing.s) {
                    Image(nsImage: AppIcons.icon(forBundleID: bundleID))
                        .resizable()
                        .frame(width: 20, height: 20)
                    if let name = AppIcons.name(forBundleID: bundleID) {
                        Text(name)
                    } else {
                        Text(bundleID)
                        Text("Not installed").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        draft.bundleIDs.removeAll { $0 == bundleID }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Remove from group")
                }
            }
            .onMove { draft.bundleIDs.move(fromOffsets: $0, toOffset: $1) }
        }
        .frame(height: 180)
        .overlay {
            if draft.bundleIDs.isEmpty {
                Text("No apps in this group").foregroundStyle(.secondary)
            }
        }
    }

    private func addFromDisk() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let info = AppIcons.appInfo(at: url), !draft.bundleIDs.contains(info.bundleID) {
                draft.bundleIDs.append(info.bundleID)
            }
        }
    }
}

/// Checkbox list of running Dock apps (one row per bundle).
private struct RunningAppChecklist: View {
    let apps: [RunningApp]
    @State var selected: Set<String>
    let onChange: (String, Bool) -> Void

    private var uniqueApps: [RunningApp] {
        var seen = Set<String>()
        return apps.filter { app in
            guard let id = app.bundleID, id != ProtectedStore.selfBundleID else { return false }
            return seen.insert(id).inserted
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(uniqueApps) { app in
                    if let bundleID = app.bundleID {
                        Toggle(isOn: Binding(
                            get: { selected.contains(bundleID) },
                            set: { include in
                                if include { selected.insert(bundleID) } else { selected.remove(bundleID) }
                                onChange(bundleID, include)
                            }
                        )) {
                            HStack {
                                Image(nsImage: app.icon).resizable().frame(width: 18, height: 18)
                                Text(app.name)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
            .padding(Tokens.Spacing.m)
        }
        .frame(width: 240, height: 300)
    }
}

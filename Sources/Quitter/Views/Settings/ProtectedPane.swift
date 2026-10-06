import AppKit
import SwiftUI

struct ProtectedPane: View {
    let store: ProtectedStore
    let monitor: AppMonitor
    @State private var selection: String?
    @State private var showingRunning = false

    var body: some View {
        Form {
            Section {
                List(store.apps, id: \.bundleID, selection: $selection) { app in
                    ProtectedRow(app: app, removable: store.isRemovable(app.bundleID))
                        .tag(app.bundleID)
                        .selectionDisabled(!store.isRemovable(app.bundleID))
                }
                .frame(minHeight: 200)
                HStack(spacing: Tokens.Spacing.s) {
                    Menu {
                        Button("Choose App…", action: chooseApp)
                        Button("Add Running App…") { showingRunning = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .accessibilityLabel("Add protected app")
                    .popover(isPresented: $showingRunning, arrowEdge: .bottom) {
                        RunningAppPicker(
                            apps: monitor.apps.filter { app in
                                guard let id = app.bundleID else { return false }
                                return !store.bundleIDs.contains(id)
                            },
                            onPick: { app in
                                if let id = app.bundleID {
                                    store.add(ProtectedApp(bundleID: id, name: app.name))
                                }
                                showingRunning = false
                            }
                        )
                    }
                    Button {
                        if let selection { store.remove(bundleID: selection) }
                        selection = nil
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(selection.map { !store.isRemovable($0) } ?? true)
                    .accessibilityLabel("Remove protected app")
                    Spacer()
                }
            } footer: {
                Text("Protected apps never appear in the list.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Protect"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let info = AppIcons.appInfo(at: url) {
                store.add(ProtectedApp(bundleID: info.bundleID, name: info.name))
            }
        }
    }
}

private struct ProtectedRow: View {
    let app: ProtectedApp
    let removable: Bool

    var body: some View {
        HStack(spacing: Tokens.Spacing.s) {
            Image(nsImage: AppIcons.icon(forBundleID: app.bundleID))
                .resizable()
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
            Text(app.name)
            Spacer()
            if !removable {
                Text("Always protected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(removable ? 1 : 0.5)
        .accessibilityElement(children: .combine)
    }
}

/// Checkbox-free pick list of running Dock apps, shared by Protected and Groups.
struct RunningAppPicker: View {
    let apps: [RunningApp]
    let onPick: (RunningApp) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if apps.isEmpty {
                Text("No other running apps")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(apps) { app in
                            Button {
                                onPick(app)
                            } label: {
                                HStack {
                                    Image(nsImage: app.icon)
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                    Text(app.name)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, Tokens.Spacing.s)
                            .padding(.vertical, 3)
                        }
                    }
                    .padding(Tokens.Spacing.s)
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(width: 240)
    }
}

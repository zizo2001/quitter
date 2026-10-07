import AppKit
import SwiftUI

struct MenuBarPane: View {
    let hider: MenuBarHider
    @State private var items: [MenuBarItem] = []
    @State private var isScanning = false
    @State private var isTrusted = MenuBarScanner.isTrusted
    @State private var failedID: String?

    var body: some View {
        Form {
            Section {
                Toggle("Hide selected menu bar icons", isOn: Binding(
                    get: { hider.isEnabled },
                    set: { hider.setEnabled($0) }
                ))
            } footer: {
                Text("Adds a \u{2039} button to the menu bar. Click it to show or hide the icons you pick below. Hidden apps keep running.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if hider.isEnabled {
                if isTrusted {
                    iconsSection
                    Section {
                        Picker("Hide again after", selection: Binding(
                            get: { hider.autoHideSeconds },
                            set: { hider.autoHideSeconds = $0 }
                        )) {
                            ForEach(MenuBarHider.autoHideChoices, id: \.self) { seconds in
                                Text(seconds == 0 ? "Never" : "\(seconds) seconds").tag(seconds)
                            }
                        }
                    }
                } else {
                    accessSection
                }
            }

            Section {
                Button("Open System Settings › Menu Bar") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } footer: {
                Text("Wi-Fi, Sound, the clock and other system icons are managed there.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: hider.isEnabled) { await refresh() }
    }

    private var accessSection: some View {
        Section {
            Label("Quitter needs Accessibility access to list and move menu bar icons.", systemImage: "hand.raised")
            HStack {
                Button("Grant Access…") {
                    MenuBarScanner.requestTrust()
                }
                Button("Check Again") {
                    Task { await refresh() }
                }
            }
        } footer: {
            Text("Privacy & Security › Accessibility › Quitter. No Screen Recording is used.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var iconsSection: some View {
        Section {
            if items.isEmpty {
                Text(isScanning ? "Looking for icons…" : "No app icons found in the menu bar.")
                    .foregroundStyle(.secondary)
            }
            ForEach(items) { item in
                MenuBarItemRow(
                    item: item,
                    isHidden: hider.hiddenIDs.contains(item.id),
                    failed: failedID == item.id,
                    disabled: hider.isMoving
                ) { hidden in
                    Task {
                        failedID = nil
                        if await !hider.setHidden(hidden, item: item) { failedID = item.id }
                    }
                }
            }
        } header: {
            HStack {
                Text("Icons")
                Spacer()
                if isScanning { ProgressView().controlSize(.small) }
                Button("Refresh") { Task { await refresh() } }
                    .buttonStyle(.borderless)
                    .disabled(isScanning)
            }
        } footer: {
            Text("Checked icons move left of the \u{2215} divider and hide. Icons from apps that aren't running aren't listed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func refresh() async {
        isTrusted = MenuBarScanner.isTrusted
        guard hider.isEnabled, isTrusted, !isScanning else { return }
        isScanning = true
        let found = await MenuBarScanner.scan()
        // One row per item, Quitter's own items excluded; stable alphabetical order.
        var seen = Set<String>()
        items = found
            .filter { $0.bundleID != ProtectedStore.selfBundleID && seen.insert($0.id).inserted }
            .sorted { ($0.appName, $0.title) < ($1.appName, $1.title) }
        isScanning = false
    }
}

private struct MenuBarItemRow: View {
    let item: MenuBarItem
    let isHidden: Bool
    let failed: Bool
    let disabled: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { isHidden }, set: { onChange($0) })) {
            HStack(spacing: Tokens.Spacing.s) {
                Image(nsImage: item.bundleID.map(AppIcons.icon(forBundleID:)) ?? NSWorkspace.shared.icon(for: .application))
                    .resizable()
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.appName)
                    if !item.title.isEmpty {
                        Text(item.title).font(.caption).foregroundStyle(.secondary)
                    }
                    if failed {
                        Text("Couldn't move this icon. Try again, or ⌘-drag it past the divider.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .disabled(disabled)
        .accessibilityLabel("Hide \(item.appName)")
    }
}

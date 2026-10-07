import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, groups, protected, shortcuts, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .groups: "Groups"
        case .protected: "Protected"
        case .shortcuts: "Shortcuts"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .groups: "square.stack"
        case .protected: "lock.shield"
        case .shortcuts: "keyboard"
        case .about: "info.circle"
        }
    }

    var tint: Color {
        switch self {
        case .general: .gray
        case .groups: .blue
        case .protected: .green
        case .shortcuts: .purple
        case .about: .gray
        }
    }
}

@MainActor
@Observable
final class SettingsNavigation {
    var selection: SettingsPane? = .general
    /// Group open in the editor sheet (a new draft or an existing group).
    var editingGroup: QuitGroup?
}

/// Everything the Settings window needs, passed in from `Dependencies`.
@MainActor
struct SettingsDependencies {
    let settings: AppSettings
    let protected: ProtectedStore
    let groups: GroupStore
    let loginItem: LoginItem
    let monitor: AppMonitor
    let navigation: SettingsNavigation
}

/// System-Settings-style sidebar + grouped form detail.
struct SettingsView: View {
    let dependencies: SettingsDependencies
    @Bindable private var navigation: SettingsNavigation

    init(dependencies: SettingsDependencies) {
        self.dependencies = dependencies
        navigation = dependencies.navigation
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $navigation.selection) { pane in
                SidebarLabel(pane: pane).tag(pane)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            detail
                .formStyle(.grouped)
                .navigationTitle(navigation.selection?.title ?? "")
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    @ViewBuilder
    private var detail: some View {
        switch navigation.selection ?? .general {
        case .general:
            GeneralPane(settings: dependencies.settings, loginItem: dependencies.loginItem)
        case .groups:
            GroupsPane(store: dependencies.groups, monitor: dependencies.monitor, navigation: navigation)
        case .protected:
            ProtectedPane(store: dependencies.protected, monitor: dependencies.monitor)
        case .shortcuts:
            ShortcutsPane(groups: dependencies.groups)
        case .about:
            AboutPane()
        }
    }
}

private struct SidebarLabel: View {
    let pane: SettingsPane

    var body: some View {
        Label {
            Text(pane.title)
        } icon: {
            Image(systemName: pane.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(pane.tint.gradient, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
    }
}

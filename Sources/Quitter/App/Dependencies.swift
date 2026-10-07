import AppKit

/// Single composition root: creates every long-lived service once.
@MainActor
final class Dependencies {
    let settings: AppSettings
    let protected: ProtectedStore
    let groups: GroupStore
    let monitor: AppMonitor
    let coordinator: QuitCoordinator
    let sampler: UsageSampler
    let loginItem: LoginItem
    let settingsWindow: SettingsWindowController
    let hotkeys: Hotkeys
    let panelModel: PanelModel
    let statusBar: StatusBarController

    init() {
        settings = AppSettings()
        protected = ProtectedStore()
        groups = GroupStore()
        monitor = AppMonitor(settings: settings)
        let settings = settings
        coordinator = QuitCoordinator(
            terminator: WorkspaceTerminator(),
            forceQuitDelay: { settings.forceQuitDelay }
        )
        panelModel = PanelModel(
            monitor: monitor, settings: settings, protected: protected, coordinator: coordinator,
            groups: groups
        )
        sampler = UsageSampler(monitor: monitor)
        let panelModel = panelModel
        sampler.onFirstSample = { panelModel.freezeSortOrder() }
        loginItem = LoginItem()
        let navigation = SettingsNavigation()
        settingsWindow = SettingsWindowController(dependencies: SettingsDependencies(
            settings: settings,
            protected: protected,
            groups: groups,
            loginItem: loginItem,
            monitor: monitor,
            navigation: navigation
        ))
        statusBar = StatusBarController(model: panelModel, settings: settings, sampler: sampler)
        let statusBar = statusBar
        let settingsWindow = settingsWindow
        panelModel.onOpenSettings = {
            statusBar.closePanel()
            settingsWindow.show()
        }
        hotkeys = Hotkeys(
            groups: groups,
            togglePanel: { statusBar.togglePanel() },
            quitGroup: { panelModel.quitGroup($0) }
        )
        statusBar.loginItem = loginItem
        statusBar.onOpenSettings = { settingsWindow.show() }
        panelModel.onSaveSelectionAsGroup = { bundleIDs in
            statusBar.closePanel()
            navigation.editingGroup = QuitGroup(name: "", bundleIDs: bundleIDs)
            settingsWindow.show(pane: .groups)
        }
    }
}

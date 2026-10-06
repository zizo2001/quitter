import AppKit

/// Single composition root: creates every long-lived service once.
@MainActor
final class Dependencies {
    let settings: AppSettings
    let protected: ProtectedStore
    let monitor: AppMonitor
    let coordinator: QuitCoordinator
    let sampler: UsageSampler
    let panelModel: PanelModel
    let statusBar: StatusBarController

    init() {
        settings = AppSettings()
        protected = ProtectedStore()
        monitor = AppMonitor(settings: settings)
        let settings = settings
        coordinator = QuitCoordinator(
            terminator: WorkspaceTerminator(),
            forceQuitDelay: { settings.forceQuitDelay }
        )
        panelModel = PanelModel(
            monitor: monitor, settings: settings, protected: protected, coordinator: coordinator
        )
        sampler = UsageSampler(monitor: monitor)
        let panelModel = panelModel
        sampler.onFirstSample = { panelModel.freezeSortOrder() }
        statusBar = StatusBarController(model: panelModel, settings: settings, sampler: sampler)
    }
}

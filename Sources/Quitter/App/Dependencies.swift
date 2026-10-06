import AppKit

/// Single composition root: creates every long-lived service once.
@MainActor
final class Dependencies {
    let settings: AppSettings
    let protected: ProtectedStore
    let monitor: AppMonitor
    let panelModel: PanelModel
    let statusBar: StatusBarController

    init() {
        settings = AppSettings()
        protected = ProtectedStore()
        monitor = AppMonitor(settings: settings)
        panelModel = PanelModel(monitor: monitor, settings: settings, protected: protected)
        statusBar = StatusBarController(model: panelModel)
    }
}

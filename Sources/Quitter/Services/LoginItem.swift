import Foundation
import Observation
import ServiceManagement

/// Launch at Login via `SMAppService.mainApp`. Only works from the built bundle, never `swift run`.
@MainActor
@Observable
final class LoginItem {
    private(set) var isEnabled = false
    private(set) var requiresApproval = false
    private(set) var errorMessage: String?

    /// False under `swift run`: there is no app bundle to register.
    let isAvailable: Bool = Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"

    init() {
        refresh()
    }

    func refresh() {
        guard isAvailable else { return }
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        requiresApproval = status == .requiresApproval
    }

    func set(_ enabled: Bool) {
        guard isAvailable else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }
}

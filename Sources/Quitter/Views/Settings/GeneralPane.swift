import SwiftUI

struct GeneralPane: View {
    @Bindable var settings: AppSettings
    let loginItem: LoginItem

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.set($0) }
                ))
                .disabled(!loginItem.isAvailable)
                .help(loginItem.isAvailable ? "" : "Available when installed")
                if !loginItem.isAvailable {
                    Text("Available when installed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if loginItem.requiresApproval {
                    Text("Approve Quitter in System Settings › General › Login Items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let error = loginItem.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Panel") {
                Toggle("Show background apps", isOn: $settings.showBackgroundApps)
                Picker("Sort by", selection: $settings.sortOrder) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
                Toggle("Show memory and CPU", isOn: $settings.showUsage)
            }

            Section("Quitting") {
                Stepper(
                    "Force Quit after \(settings.forceQuitDelaySeconds) s",
                    value: $settings.forceQuitDelaySeconds,
                    in: AppSettings.forceQuitDelayRange
                )
                Toggle("Close panel after quitting", isOn: $settings.closePanelAfterQuit)
                Toggle("Ask before quitting", isOn: $settings.confirmBeforeQuit)
            }
        }
    }
}

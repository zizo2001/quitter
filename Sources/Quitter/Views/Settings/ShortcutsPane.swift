import KeyboardShortcuts
import SwiftUI

struct ShortcutsPane: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Open Quitter:", name: .togglePanel)
            } footer: {
                Text("Works from any app. Press it again to close the panel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

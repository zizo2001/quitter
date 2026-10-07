import KeyboardShortcuts
import SwiftUI

struct ShortcutsPane: View {
    let groups: GroupStore

    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Open Quitter:", name: .togglePanel)
            } footer: {
                Text("Works from any app. Press it again to close the panel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                if groups.groups.isEmpty {
                    Text("Create a group in Groups to give it a shortcut.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(groups.groups) { group in
                        KeyboardShortcuts.Recorder("Quit \(group.name):", name: .group(group.id))
                    }
                }
            } header: {
                Text("Quit Groups")
            } footer: {
                Text("Quits the group's running apps right away, without opening the panel. Protected apps are skipped.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

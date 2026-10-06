import AppKit
import SwiftUI

struct AboutPane: View {
    private static let projectFolder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Projects/Programming/quitter", isDirectory: true)

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    var body: some View {
        VStack(spacing: Tokens.Spacing.m) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text("Quitter \(version)")
                .font(.title2.weight(.semibold))
            Text("Multi-quit for the menu bar")
                .foregroundStyle(.secondary)
            Text("Built by Aziz Ali")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Reveal Project Folder") {
                NSWorkspace.shared.activateFileViewerSelecting([Self.projectFolder])
            }
            .disabled(!FileManager.default.fileExists(atPath: Self.projectFolder.path))
            .padding(.top, Tokens.Spacing.s)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

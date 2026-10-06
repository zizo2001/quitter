#if DEBUG
import AppKit
import ScreenCaptureKit

/// Debug-only verification aid: captures Quitter's own on-screen windows to PNG when
/// the distributed notification `com.azizali.quitter.debug.snapshot` arrives.
/// Output directory comes from `QUITTER_SNAPSHOT_DIR`. Own-process capture needs no
/// Screen Recording permission. Compiled out of release builds.
@MainActor
enum DebugSnapshot {
    private static var observer: NSObjectProtocol?

    static func install() {
        guard let path = ProcessInfo.processInfo.environment["QUITTER_SNAPSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: path)
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.azizali.quitter.debug.snapshot"),
            object: nil,
            queue: .main
        ) { note in
            let name = (note.object as? String) ?? "snapshot"
            Task { @MainActor in await capture(name: name, into: directory) }
        }
    }

    private static func capture(name: String, into directory: URL) async {
        do {
            let content = try await SCShareableContent.currentProcess
            let windows = content.windows.filter { $0.isOnScreen && $0.frame.height > 40 && $0.frame.width < 1200 && $0.frame.height < 1200 }
            for (index, window) in windows.enumerated() {
                let filter = SCContentFilter(desktopIndependentWindow: window)
                let config = SCStreamConfiguration()
                config.width = Int(window.frame.width * 2)
                config.height = Int(window.frame.height * 2)
                config.showsCursor = false
                config.ignoreShadowsSingleWindow = false
                let image = try await SCScreenshotManager.captureImage(
                    contentFilter: filter, configuration: config
                )
                let rep = NSBitmapImageRep(cgImage: image)
                guard let png = rep.representation(using: .png, properties: [:]) else { continue }
                let suffix = windows.count > 1 ? "-\(index)" : ""
                try png.write(to: directory.appendingPathComponent("\(name)\(suffix).png"))
            }
            NSLog("DebugSnapshot: wrote \(windows.count) window(s) for \(name)")
        } catch {
            NSLog("DebugSnapshot failed: \(error)")
        }
    }
}
#endif

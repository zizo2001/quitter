// Renders Resources/AppIcon.icns: red gradient squircle with a white xmark.
// Run from the repo root: `swift scripts/make-icon.swift` (or `make icon`).
import AppKit

let canvas: CGFloat = 1024
let outputURL = URL(fileURLWithPath: "Resources/AppIcon.icns")

func color(_ hex: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

/// Draws the master artwork into the current graphics context at 1024×1024 points.
func drawMaster() {
    // macOS icon grid: 824×824 body centred on a 1024 canvas.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.shadowBlurRadius = 24
    shadow.set()
    color(0xC0392B).setFill()
    squircle.fill()
    NSGraphicsContext.restoreGraphicsState()

    if let gradient = NSGradient(starting: color(0xFF6B6B), ending: color(0xC0392B)) {
        // angle -90 draws from top to bottom.
        gradient.draw(in: squircle, angle: -90)
    }

    let config = NSImage.SymbolConfiguration(pointSize: 560, weight: .bold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    guard
        let symbol = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    else {
        fatalError("xmark symbol unavailable")
    }
    let size = symbol.size
    let origin = NSPoint(x: (canvas - size.width) / 2, y: (canvas - size.height) / 2)
    symbol.draw(in: NSRect(origin: origin, size: size))
}

/// Renders one iconset PNG at 72 dpi (logical size = pixel size). macOS 27 places legacy .icns
/// art on its icon plate using the PNG's DPI: the original 1024-pt-for-every-size metadata drew
/// a magnified corner, 144-dpi @2x files drew the art shrunk into a corner.
func renderPNG(pixels: Int) -> Data? {
    guard
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: rep)
    else { return nil }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(pixels) / canvas)
    transform.concat()
    drawMaster()
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

// Only the large representations, like other legacy-icon apps: with the full 16…1024 set the
// system picked a small rep for 96-pt @2x drawing and upscaled it (blurry); it downsamples
// cleanly from these two.
let entries: [(name: String, pixels: Int)] = [
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

let fm = FileManager.default
let iconset = fm.temporaryDirectory.appendingPathComponent("Quitter-\(UUID().uuidString).iconset")
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: iconset) }

for entry in entries {
    guard let png = renderPNG(pixels: entry.pixels) else {
        fatalError("render failed for \(entry.name)")
    }
    try png.write(to: iconset.appendingPathComponent("\(entry.name).png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", outputURL.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    fatalError("iconutil failed with status \(iconutil.terminationStatus)")
}
print("Wrote \(outputURL.path)")

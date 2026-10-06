// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Quitter",
    platforms: [.macOS(.v26)],
    dependencies: [
        // 3.1.0: macOS 26+/27 recorder fix (recording ended immediately on 2.4.0) and Swift 6.3 release-build crash fix.
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "3.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "Quitter",
            dependencies: ["KeyboardShortcuts"],
            path: "Sources/Quitter",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "QuitterTests",
            dependencies: ["Quitter"],
            path: "Tests/QuitterTests"
        ),
    ]
)

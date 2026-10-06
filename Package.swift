// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Quitter",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
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

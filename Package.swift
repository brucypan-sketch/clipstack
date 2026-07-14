// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ClipStack",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "ClipStackKit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "ClipStackChecks",
            dependencies: ["ClipStackKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)

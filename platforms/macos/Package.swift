// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FirehawkFocus",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "FirehawkFocus", targets: ["FirehawkFocus"]),
    ],
    targets: [
        .target(name: "FirehawkDSP"),
        .executableTarget(
            name: "FirehawkFocus",
            dependencies: ["FirehawkDSP"],
            path: "Sources/FirehawkFocus",
            resources: [
                .copy("Resources/FocusModel.js"),
                .copy("Resources/Sounds"),
                .copy("Resources/Ambience"),
                .copy("Resources/AppIcon.icns")
            ]
        ),
        .testTarget(
            name: "FirehawkFocusTests",
            dependencies: ["FirehawkFocus", "FirehawkDSP"],
            path: "Tests/FirehawkFocusTests"
        ),
    ]
)

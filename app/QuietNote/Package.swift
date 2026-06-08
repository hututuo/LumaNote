// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "QuietNote",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "QuietNote", targets: ["QuietNote"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "1.9.4")
    ],
    targets: [
        .executableTarget(
            name: "QuietNote",
            dependencies: [
                "KeyboardShortcuts"
            ],
            path: "Sources"
        )
    ]
)

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
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "1.9.4"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0")
    ],
    targets: [
        .executableTarget(
            name: "QuietNote",
            dependencies: [
                "KeyboardShortcuts",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "QuietNoteTests",
            dependencies: ["QuietNote"],
            path: "Tests"
        )
    ]
)

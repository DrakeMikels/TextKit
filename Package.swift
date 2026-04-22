// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TextKit",
    platforms: [
        .macOS("26.0")
    ],
    targets: [
        .executableTarget(
            name: "TextKit",
            path: "Sources"
        ),
        .testTarget(
            name: "TextKitTests",
            dependencies: ["TextKit"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)

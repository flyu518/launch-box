// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "launch-box",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "LaunchBoxCore", targets: ["LaunchBoxCore"]),
        .executable(name: "LaunchBox", targets: ["LaunchBox"])
    ],
    targets: [
        .target(
            name: "LaunchBoxCore",
            path: "Sources/LaunchBoxCore"
        ),
        .executableTarget(
            name: "LaunchBox",
            dependencies: ["LaunchBoxCore"],
            path: "Sources/LaunchBox"
        ),
        .testTarget(
            name: "LaunchBoxCoreTests",
            dependencies: ["LaunchBoxCore"],
            path: "Tests/LaunchBoxCoreTests"
        )
    ]
)

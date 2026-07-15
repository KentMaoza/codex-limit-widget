// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexLimitWidget",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CodexLimitCore", targets: ["CodexLimitCore"]),
        .executable(name: "CodexLimitApp", targets: ["CodexLimitApp"]),
        .executable(name: "LimitWidget", targets: ["LimitWidget"])
    ],
    targets: [
        .target(name: "CodexLimitCore"),
        .executableTarget(
            name: "CodexLimitApp",
            dependencies: ["CodexLimitCore"]
        ),
        .executableTarget(
            name: "LimitWidget",
            dependencies: ["CodexLimitCore"]
        ),
        .testTarget(
            name: "CodexLimitCoreTests",
            dependencies: ["CodexLimitCore"]
        )
    ]
)

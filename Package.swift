// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "capslox",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "capslox", targets: ["capslox"]),
        .library(name: "CapsloxCore", targets: ["CapsloxCore"])
    ],
    targets: [
        .target(name: "CapsloxCore"),
        .executableTarget(
            name: "capslox",
            dependencies: ["CapsloxCore"]
        ),
        .testTarget(
            name: "CapsloxCoreTests",
            dependencies: ["CapsloxCore"],
            path: "tests/CapsloxCoreTests"
        )
    ]
)

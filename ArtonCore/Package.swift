// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ArtonCore",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ArtonCore",
            targets: ["ArtonCore"]
        ),
    ],
    targets: [
        .target(
            name: "ArtonCore",
            dependencies: [],
            path: "Sources/ArtonCore"
        ),
        .testTarget(
            name: "ArtonCoreTests",
            dependencies: ["ArtonCore"],
            path: "Tests/ArtonCoreTests"
        ),
    ]
)

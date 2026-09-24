// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SimJevUse",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(name: "SimJevUse", targets: ["SimJevUse"]),
    ],
    targets: [
        .executableTarget(
            name: "SimJevUse",
            dependencies: ["SimJevUseKit"]
        ),
        .target(name: "SimJevUseKit"),
        .testTarget(
            name: "SimJevUseKitTests",
            dependencies: ["SimJevUseKit"]
        ),
    ]
)

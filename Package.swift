// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SimJevUse",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(name: "SimJevUse", targets: ["SimJevUse"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.2"),
        .package(url: "https://github.com/d-date/swift-jev", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "SimJevUse",
            dependencies: [
                "SimJevUseKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
        ),
        .target(
            name: "SimJevUseKit",
            dependencies: [
                .product(name: "Jev", package: "swift-jev"),
            ],
        ),
        .testTarget(
            name: "SimJevUseKitTests",
            dependencies: ["SimJevUseKit"],
        ),
    ],
)

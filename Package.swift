// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "JevSimUse",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(name: "jev-sim-use", targets: ["JevSimUse"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.2"),
        .package(url: "https://github.com/d-date/swift-jev", from: "1.0.0"),
        .package(url: "https://github.com/Ryu0118/FileManagerProtocol", from: "0.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "JevSimUse",
            dependencies: ["JevSimUseCLI"],
        ),
        .target(
            name: "JevSimUseCLI",
            dependencies: [
                "JevSimUseKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
        ),
        .target(
            name: "JevSimUseKit",
            dependencies: [
                .product(name: "Jev", package: "swift-jev"),
                .product(name: "FileManagerProtocol", package: "FileManagerProtocol"),
            ],
        ),
        .testTarget(
            name: "JevSimUseCLITests",
            dependencies: ["JevSimUseCLI"],
        ),
        .testTarget(
            name: "JevSimUseKitTests",
            dependencies: ["JevSimUseKit"],
        ),
    ],
)

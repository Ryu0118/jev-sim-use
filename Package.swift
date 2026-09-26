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
        .package(url: "https://github.com/Ryu0118/ProcessRunning", from: "0.3.0"),
        .package(url: "https://github.com/swiftlang/swift-subprocess", from: "1.0.0"),
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
                .product(name: "ProcessRunning", package: "ProcessRunning"),
                .product(name: "Subprocess", package: "swift-subprocess"),
            ],
            plugins: ["EmbedSkill"],
        ),
        // Explicit paths: `plugins/jev-sim-use` is the agent plugin, and on a case-insensitive disk it is also
        // SwiftPM's default `Plugins` directory.
        .plugin(
            name: "EmbedSkill",
            capability: .buildTool(),
            dependencies: ["EmbedSkillTool"],
            path: "BuildPlugins/EmbedSkill",
        ),
        .executableTarget(
            name: "EmbedSkillTool",
            path: "BuildPlugins/EmbedSkillTool",
        ),
        .testTarget(
            name: "JevSimUseCLITests",
            dependencies: ["JevSimUseCLI"],
        ),
        .testTarget(
            name: "JevSimUseContractTests",
            dependencies: ["JevSimUseKit"],
        ),
        .testTarget(
            name: "JevSimUseKitTests",
            dependencies: ["JevSimUseKit"],
        ),
    ],
)

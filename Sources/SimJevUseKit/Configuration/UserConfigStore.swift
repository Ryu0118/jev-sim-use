import Foundation

/// Reads and writes `UserConfig` at `$XDG_CONFIG_HOME/sim-jev-use/config.json`
/// (default `~/.config/sim-jev-use/config.json`).
public struct UserConfigStore: Sendable {
    /// The config file location.
    public let fileURL: URL

    /// Creates a store; `environment` is injectable so tests can point `XDG_CONFIG_HOME` at a temp directory.
    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        let base = environment["XDG_CONFIG_HOME"].flatMap { $0.isEmpty ? nil : URL(filePath: $0) }
            ?? URL.homeDirectory.appending(path: ".config")
        fileURL = base.appending(path: "sim-jev-use/config.json")
    }

    /// The stored config, or an empty one when the file does not exist yet.
    public func load() throws -> UserConfig {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return UserConfig() }
        return try JSONDecoder().decode(UserConfig.self, from: Data(contentsOf: fileURL))
    }

    /// Writes `config`, creating the directory if needed.
    public func save(_ config: UserConfig) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(config).write(to: fileURL, options: .atomic)
    }
}

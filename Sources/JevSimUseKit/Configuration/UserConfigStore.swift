import FileManagerProtocol
import Foundation

/// Reads and writes `UserConfig` at `$XDG_CONFIG_HOME/jev-sim-use/config.json`
/// (default `$HOME/.config/jev-sim-use/config.json`).
package struct UserConfigStore: Sendable {
    /// The config file location.
    package let fileURL: URL
    private let fileManager: any FileManagerProtocol

    /// Creates a store for the config directory `environment` points at.
    package init(environment: [String: String], fileManager: some FileManagerProtocolMacOS = FileManager.default) {
        fileURL = UserDirectories(environment: environment, fileManager: fileManager).config
            .appending(path: "jev-sim-use/config.json")
        self.fileManager = fileManager
    }

    /// The stored config, or an empty one when the file does not exist yet.
    package func load() throws -> UserConfig {
        guard let data = fileManager.contents(atPath: fileURL.path(percentEncoded: false)) else { return UserConfig() }
        return try JSONDecoder().decode(UserConfig.self, from: data)
    }

    /// Writes `config`, creating the directory if needed.
    package func save(_ config: UserConfig) throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard try fileManager.createFile(atPath: fileURL.path(percentEncoded: false), contents: encoder.encode(config))
        else { throw UserConfigStoreError.writeFailed(fileURL) }
    }
}

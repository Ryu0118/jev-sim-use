import FileManagerProtocol
import Foundation

/// Per-user base directories, resolved from `HOME` and the XDG Base Directory variables.
package struct UserDirectories: Sendable, Hashable {
    /// `$HOME`, falling back to the current user's home.
    package let home: URL
    /// `$XDG_CONFIG_HOME`, default `$HOME/.config`: settings the user edits.
    package let config: URL
    /// `$XDG_STATE_HOME`, default `$HOME/.local/state`: data the tool keeps between runs.
    package let state: URL

    /// Resolves the directories from `environment`; empty values count as unset, as the XDG spec requires.
    package init(environment: [String: String], fileManager: some FileManagerProtocolMacOS = FileManager.default) {
        func directory(_ key: String) -> URL? {
            environment[key].flatMap { $0.isEmpty ? nil : URL(filePath: $0) }
        }
        home = directory("HOME") ?? fileManager.homeDirectoryForCurrentUser
        config = directory("XDG_CONFIG_HOME") ?? home.appending(path: ".config")
        state = directory("XDG_STATE_HOME") ?? home.appending(path: ".local/state")
    }
}

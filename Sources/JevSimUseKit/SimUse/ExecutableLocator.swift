import FileManagerProtocol
import Foundation

/// Resolves a command name against `PATH`, the way a shell or `/usr/bin/env` would.
///
/// Resolving here instead of launching through `/usr/bin/env` keeps "not installed"
/// distinguishable from the child's own exit status 127, and yields the path to report.
package struct ExecutableLocator: Sendable {
    private let searchPath: String
    private let fileManager: any FileManagerProtocol

    /// The raw `PATH` that was searched, for error messages.
    package var searchedPath: String {
        searchPath
    }

    /// Creates a locator over `environment["PATH"]`.
    package init(environment: [String: String], fileManager: some FileManagerProtocol = FileManager.default) {
        searchPath = environment["PATH"] ?? ""
        self.fileManager = fileManager
    }

    /// The first executable named `name` in `PATH` order, or `nil`.
    package func locate(_ name: String) -> URL? {
        searchPath
            .split(separator: ":", omittingEmptySubsequences: true)
            .lazy
            .map { URL(filePath: String($0)).appending(path: name) }
            .first { fileManager.isExecutableFile(atPath: $0.path(percentEncoded: false)) }
    }
}

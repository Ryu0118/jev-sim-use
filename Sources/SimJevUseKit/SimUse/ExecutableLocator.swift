import Foundation

/// Resolves a command name against `PATH`, the way a shell or `/usr/bin/env` would.
///
/// Resolving here instead of launching through `/usr/bin/env` keeps "not installed"
/// distinguishable from the child's own exit status 127, and yields the path to report.
public struct ExecutableLocator: Sendable {
    private let searchPath: String
    private let isExecutable: @Sendable (String) -> Bool

    /// The raw `PATH` that was searched, for error messages.
    public var searchedPath: String {
        searchPath
    }

    /// Creates a locator over `environment["PATH"]`. `isExecutable` is injectable for tests.
    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isExecutable: @escaping @Sendable (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) },
    ) {
        searchPath = environment["PATH"] ?? ""
        self.isExecutable = isExecutable
    }

    /// The first executable named `name` in `PATH` order, or `nil`.
    public func locate(_ name: String) -> URL? {
        searchPath
            .split(separator: ":", omittingEmptySubsequences: true)
            .lazy
            .map { URL(filePath: String($0)).appending(path: name) }
            .first { isExecutable($0.path(percentEncoded: false)) }
    }
}

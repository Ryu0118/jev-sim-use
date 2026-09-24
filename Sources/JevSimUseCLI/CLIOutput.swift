import Foundation

/// Where commands write. Injected so CLI tests can record what a command prints.
package struct CLIOutput: Sendable {
    /// Writes one line of data to stdout.
    package var standardOutput: @Sendable (String) -> Void
    /// Writes one line of progress or diagnostics to stderr.
    package var standardError: @Sendable (String) -> Void

    /// The process's real stdout and stderr.
    package static let live = CLIOutput(
        standardOutput: { print($0) },
        standardError: { FileHandle.standardError.write(Data(($0 + "\n").utf8)) },
    )

    package init(
        standardOutput: @escaping @Sendable (String) -> Void,
        standardError: @escaping @Sendable (String) -> Void,
    ) {
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

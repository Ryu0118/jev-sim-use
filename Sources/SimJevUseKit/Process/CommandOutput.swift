import Foundation

/// The captured result of one finished child process.
package struct CommandOutput: Sendable, Hashable {
    /// The process exit status.
    package var exitCode: Int32
    /// Everything the process wrote to standard output.
    package var stdout: Data
    /// Everything the process wrote to standard error, decoded as UTF-8.
    package var stderr: String

    /// Creates an output from already captured streams.
    package init(exitCode: Int32, stdout: Data, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

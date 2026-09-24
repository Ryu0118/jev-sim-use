import Foundation

/// The captured result of one finished child process.
public struct CommandOutput: Sendable, Hashable {
    /// The process exit status.
    public var exitCode: Int32
    /// Everything the process wrote to standard output.
    public var stdout: Data
    /// Everything the process wrote to standard error, decoded as UTF-8.
    public var stderr: String

    /// Creates an output from already captured streams.
    public init(exitCode: Int32, stdout: Data, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

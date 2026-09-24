import Foundation
import ProcessRunning
import Subprocess
import System

/// Runs commands through swift-subprocess (via `ProcessRunning`), collecting stdout and stderr concurrently.
///
/// No grace-period logic is needed for a grandchild that inherits the pipes: swift-subprocess 1.0 cancels the
/// pending reads once the child exits and drains what is already buffered.
package struct SubprocessCommandRunner: CommandRunning {
    /// Upper bound on captured bytes per stream; `sim-use ui --json` output stays far below it.
    static let outputLimit = 16 * 1024 * 1024

    private let processRunner: any ProcessRunning

    package init(processRunner: some ProcessRunning = ProcessRunner()) {
        self.processRunner = processRunner
    }

    /// Runs `executable` to completion and returns its exit status and output.
    package func run(_ executable: URL, arguments: [String]) async throws -> CommandOutput {
        let result = try await processRunner.run(
            .path(FilePath(executable.path(percentEncoded: false))),
            arguments: Arguments(arguments),
            environment: .inherit,
            workingDirectory: nil,
            platformOptions: PlatformOptions(),
            input: .none,
            output: .bytes(limit: Self.outputLimit),
            error: .bytes(limit: Self.outputLimit),
        )
        return CommandOutput(
            exitCode: Self.exitCode(result.terminationStatus),
            stdout: Data(result.standardOutput),
            stderr: String(bytes: result.standardError, encoding: .utf8) ?? "",
        )
    }

    /// A signalled child reports `128 + signal`, the shell convention.
    static func exitCode(_ status: TerminationStatus) -> Int32 {
        switch status {
        case let .exited(code): code
        case let .signaled(signal): 128 + signal
        }
    }
}

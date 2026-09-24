import Foundation

/// Runs commands with `Foundation.Process`, draining stdout and stderr concurrently.
package struct ProcessCommandRunner: CommandRunning {
    /// How long to keep reading after exit. A grandchild that inherited the pipes
    /// would otherwise hold back end of file until it exits too.
    static let drainGracePeriod = DispatchTimeInterval.milliseconds(300)

    /// Creates a runner.
    package init() {}

    /// Launches `executable` and terminates it if the calling task is cancelled.
    package func run(_ executable: URL, arguments: [String]) async throws -> CommandOutput {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        let stdout = PipeCollector()
        let stderr = PipeCollector()
        process.standardOutput = stdout.pipe
        process.standardError = stderr.pipe

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let drained = DispatchGroup()
                stdout.start(group: drained)
                stderr.start(group: drained)
                process.terminationHandler = { _ in
                    DispatchQueue.global().async {
                        _ = drained.wait(timeout: .now() + Self.drainGracePeriod)
                        continuation.resume()
                    }
                }
                do {
                    try process.run()
                } catch {
                    _ = (stdout.finish(), stderr.finish())
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            process.terminate()
        }
        return CommandOutput(
            exitCode: process.terminationStatus,
            stdout: stdout.finish(),
            stderr: String(bytes: stderr.finish(), encoding: .utf8) ?? "",
        )
    }
}

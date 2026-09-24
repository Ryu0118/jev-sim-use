import Foundation

/// Runs commands with `Foundation.Process`, draining stdout and stderr concurrently.
public struct ProcessCommandRunner: CommandRunning {
    /// Creates a runner.
    public init() {}

    /// Launches `executable` and terminates it if the calling task is cancelled.
    public func run(_ executable: URL, arguments: [String]) async throws -> CommandOutput {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        let stdout = PipeCollector()
        let stderr = PipeCollector()
        let group = DispatchGroup()
        stdout.drain(stdoutPipe.fileHandleForReading, group: group)
        stderr.drain(stderrPipe.fileHandleForReading, group: group)
        group.enter()
        process.terminationHandler = { _ in group.leave() }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            throw error
        }
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                group.notify(queue: .global()) { continuation.resume() }
            }
        } onCancel: {
            process.terminate()
        }
        return CommandOutput(
            exitCode: process.terminationStatus,
            stdout: stdout.data,
            stderr: String(bytes: stderr.data, encoding: .utf8) ?? "",
        )
    }
}

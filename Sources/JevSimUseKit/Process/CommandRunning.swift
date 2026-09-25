import Foundation

/// Runs an executable to completion. A seam so tests never spawn `sim-use`.
package protocol CommandRunning: Sendable {
    /// Runs `executable` with `arguments`, and `environment` added to the inherited one, and returns once the
    /// process has exited and both output streams are fully drained.
    func run(_ executable: URL, arguments: [String], environment: [String: String]) async throws -> CommandOutput
}

extension CommandRunning {
    /// Runs `executable` with `arguments` in the inherited environment.
    func run(_ executable: URL, arguments: [String]) async throws -> CommandOutput {
        try await run(executable, arguments: arguments, environment: [:])
    }
}

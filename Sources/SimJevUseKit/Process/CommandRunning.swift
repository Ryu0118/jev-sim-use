import Foundation

/// Runs an executable to completion. A seam so tests never spawn `sim-use`.
public protocol CommandRunning: Sendable {
    /// Runs `executable` with `arguments` and returns once the process has exited
    /// and both output streams are fully drained.
    func run(_ executable: URL, arguments: [String]) async throws -> CommandOutput
}

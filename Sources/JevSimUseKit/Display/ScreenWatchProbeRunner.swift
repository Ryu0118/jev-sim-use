import Foundation

/// Watches a simulator's screen for a while and reports each content change with its wall-clock time, so the delay
/// from an action sent at a known time to the first change and to the last can be measured from outside.
package struct ScreenWatchProbeRunner: Sendable {
    private let environment: [String: String]

    /// Creates a probe that finds the display as a run does.
    package init(environment: [String: String]) {
        self.environment = environment
    }

    /// Watches `simulatorID` for `duration`, passing the time of each frame that changed the content to `report`.
    package func run(
        simulatorID: String, for duration: Duration, report: @escaping @Sendable (Date) -> Void,
    ) async throws(ScreenWatchError) {
        let opener = SimulatorScreenWatchOpener(environment: environment) { instant in
            report(Date.now.addingTimeInterval(-((ContinuousClock.now - instant) / .seconds(1))))
        }
        let watcher = try await opener.open(simulatorID: simulatorID)
        defer { watcher.close() }
        // Cancellation only ends the watch early.
        try? await Task.sleep(for: duration)
    }
}

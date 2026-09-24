/// Observe → plan → act, until Jev judges the goal reached or a stop condition hits.
///
/// sim-use has no launch verb, so a run starts from whatever is on screen.
package struct AgentLoop: Sendable {
    let driver: any DeviceDriving
    let planner: any StepPlanning
    let configuration: AgentConfiguration
    let report: @Sendable (AgentEvent) -> Void

    /// Creates a loop. `report` receives progress events as they happen.
    package init(
        driver: any DeviceDriving,
        planner: any StepPlanning,
        configuration: AgentConfiguration,
        report: @escaping @Sendable (AgentEvent) -> Void = { _ in },
    ) {
        self.driver = driver
        self.planner = planner
        self.configuration = configuration
        self.report = report
    }

    /// Runs until an outcome is reached. Throws only for sim-use or Jev failures.
    ///
    /// `history` continues an earlier run: Jev sees it and step numbers carry on, but `maxSteps` and loop detection
    /// start fresh, so a run that stopped at the step limit or stalled can make progress when resumed.
    package func run(continuing history: [HistoryEntry] = []) async throws -> AgentRunResult {
        var progress = AgentProgress(history: history)
        while true {
            try Task.checkCancellation()
            let observation = try await observeSettled()
            if let outcome = progress.record(observation, stallLimit: configuration.stallLimit) {
                return AgentRunResult(outcome: outcome, history: progress.history)
            }
            let plan = try await plan(for: observation.snapshot, progress: progress)
            switch decide(on: plan, progress: progress) {
            case let .stop(outcome):
                return AgentRunResult(outcome: outcome, history: progress.history)
            case let .act(action):
                let disappeared = try await execute(action, on: observation.snapshot)
                progress.recordAction(action, disappeared: disappeared)
            }
        }
    }
}

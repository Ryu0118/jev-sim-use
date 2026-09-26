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
        var context = AgentLoopContext(progress: AgentProgress(history: history))
        var state = AgentLoopState.observing(pending: nil)
        while true {
            switch state {
            case let .observing(pending): state = try await observe(pending: pending, context: &context)
            case let .planning(observation): state = try await planStep(on: observation, context: &context)
            case let .deciding(step): state = try await decideStep(step, context: &context)
            case let .finished(outcome):
                // The last step took no action, so its time is reported here; a run that stops right after an action
                // has none left.
                if context.timing.total > 0 {
                    report(.timed(step: context.progress.nextStep, timing: context.timing))
                }
                return AgentRunResult(
                    outcome: outcome, history: context.progress.history, timing: context.finishedTiming + context.timing,
                )
            }
        }
    }
}

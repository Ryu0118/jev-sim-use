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
        var expectedToFinish = false
        var actedOn: UISnapshot?
        while true {
            try Task.checkCancellation()
            let observation = try await observeAfterAction(on: actedOn)
            if let outcome = progress.record(observation, stallLimit: configuration.stallLimit) {
                return AgentRunResult(outcome: outcome, history: progress.history)
            }
            // Jev said the last action would finish the goal and the screen did change: stop without asking again
            // (as jev-use does). This also settles relative goals ("the next photo") that the final screen alone
            // cannot prove.
            if expectedToFinish, progress.history.last?.screenChanged == true {
                return AgentRunResult(outcome: .goalReached(steps: progress.steps), history: progress.history)
            }
            let plan = try await plan(for: observation.snapshot, progress: progress)
            expectedToFinish = plan.finishes.value >= ActionPolicy.finishMinimum
            if let scan = ScanFirst.override(
                plan, on: observation.snapshot, goal: configuration.goal, notes: configuration.notes,
                alreadyScanned: progress.hasScannedCurrentTitle, tried: progress.ineffectiveActions,
            ), progress.steps < configuration.maxSteps {
                report(.scanning(step: progress.nextStep))
                progress.markScanned()
                expectedToFinish = false
                let disappeared = try await execute(scan, on: observation.snapshot)
                progress.recordAction(scan, disappeared: disappeared)
                actedOn = observation.snapshot
                continue
            }
            var decision = decide(on: plan, progress: progress)
            if shouldRetryWithHints(decision, on: observation.snapshot) {
                report(.retryingWithHints(step: progress.nextStep))
                let hinted = try await self.plan(for: observation.snapshot, progress: progress, withHints: true)
                expectedToFinish = hinted.finishes.value >= ActionPolicy.finishMinimum
                decision = decide(on: hinted, progress: progress)
            }
            switch decision {
            case let .stop(outcome):
                return AgentRunResult(outcome: outcome, history: progress.history)
            case let .act(action):
                // The last action's effect arrived while Jev was deciding: its plan is for a screen that is gone.
                guard try await isStillCurrent(observation.snapshot, progress: progress) else {
                    actedOn = nil
                    continue
                }
                let disappeared = try await execute(action, on: observation.snapshot)
                progress.recordAction(action, disappeared: disappeared)
                actedOn = observation.snapshot
            }
        }
    }
}

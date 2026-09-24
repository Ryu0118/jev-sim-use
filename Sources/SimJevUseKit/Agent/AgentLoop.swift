/// Observe → plan → act, until Jev judges the goal reached or a stop condition hits.
///
/// sim-use has no launch verb, so a run starts from whatever is on screen.
public struct AgentLoop: Sendable {
    let driver: any DeviceDriving
    let planner: any StepPlanning
    let configuration: AgentConfiguration
    let report: @Sendable (AgentEvent) -> Void

    /// Creates a loop. `report` receives progress events as they happen.
    public init(
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
    public func run() async throws -> AgentOutcome {
        var progress = AgentProgress()
        while true {
            try Task.checkCancellation()
            let observation = try await driver.observe()
            if let outcome = progress.record(observation, stallLimit: configuration.stallLimit) {
                return outcome
            }
            let plan = try await plan(for: observation.snapshot, progress: progress)
            if let outcome = verdict(on: plan, progress: progress) {
                return outcome
            }
            let disappeared = try await execute(plan.action, platform: observation.snapshot.platform)
            progress.recordAction(plan.action, disappeared: disappeared)
        }
    }
}

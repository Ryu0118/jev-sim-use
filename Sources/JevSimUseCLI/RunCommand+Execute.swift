import JevSimUseKit

extension RunCommand {
    func execute(context: CLIContext) async throws -> AgentOutcome {
        let runner = RunGoalRunner(
            bootstrap: SimUseBootstrap(locator: ExecutableLocator(environment: context.environment)),
            configStore: UserConfigStore(environment: context.environment),
            environment: context.environment,
        )
        let request = RunGoalRequest(
            goal: goal, texts: texts, maxSteps: maxSteps, minConfidence: minConfidence,
            deviceID: connection.device, baseURL: connection.baseURL, model: connection.model,
        )
        return try await runner.run(request) { context.output.standardError($0.description) }
    }
}

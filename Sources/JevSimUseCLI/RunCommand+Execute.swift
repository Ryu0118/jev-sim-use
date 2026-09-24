import Jev
import JevSimUseKit

extension RunCommand {
    func execute(context: CLIContext) async throws -> AgentOutcome {
        let settings = try connection.jevSettings(environment: context.environment)
        let bootstrap = SimUseBootstrap(locator: ExecutableLocator(environment: context.environment))
        let client = try await bootstrap.connect(deviceID: connection.resolvedDevice(environment: context.environment))
        context.output.standardError("Device: \(client.device.name) (\(client.device.deviceId)); Jev: \(settings.endpoint)")
        let policy = RoutingPolicy(escalateBelow: minConfidence, autoAtOrAbove: max(minConfidence, 0.85))
        let loop = AgentLoop(
            driver: client,
            planner: JevStepPlanner(client: settings.makeClient()),
            configuration: AgentConfiguration(goal: goal, texts: texts, maxSteps: maxSteps, policy: policy),
            report: { context.output.standardError($0.description) },
        )
        return try await loop.run()
    }
}

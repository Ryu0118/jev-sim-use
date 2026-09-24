import Foundation
import Jev

/// Connects to sim-use and Jev and works toward one goal.
package struct RunGoalRunner: Sendable {
    private let bootstrap: SimUseBootstrap
    private let configStore: UserConfigStore
    private let environment: [String: String]
    private let makePlanner: @Sendable (JevSettings) -> any StepPlanning

    package init(
        bootstrap: SimUseBootstrap,
        configStore: UserConfigStore,
        environment: [String: String],
        makePlanner: @escaping @Sendable (JevSettings) -> any StepPlanning = { JevStepPlanner(client: $0.makeClient()) },
    ) {
        self.bootstrap = bootstrap
        self.configStore = configStore
        self.environment = environment
        self.makePlanner = makePlanner
    }

    /// Resolves settings, pins the device, and runs the agent loop until it stops.
    package func run(
        _ request: RunGoalRequest,
        report: @escaping @Sendable (RunGoalEvent) -> Void,
    ) async throws -> AgentOutcome {
        let settings = try JevSettings.resolve(
            baseURLFlag: request.baseURL, modelFlag: request.model, config: configStore.load(), environment: environment,
        )
        let connection = try await bootstrap.connect(
            deviceID: SimUseBootstrap.deviceID(flag: request.deviceID, environment: environment),
        )
        connection.versionWarning.map { report(.warning($0)) }
        report(.connected(device: connection.client.device, endpoint: settings.endpoint))

        return try await AgentLoop(
            driver: connection.client,
            planner: makePlanner(settings),
            configuration: AgentConfiguration(
                goal: request.goal, texts: request.texts, maxSteps: request.maxSteps,
                actionPolicy: ActionPolicy(minimumSupport: request.minConfidence),
            ),
            report: { report(.agent($0)) },
        ).run().outcome
    }
}

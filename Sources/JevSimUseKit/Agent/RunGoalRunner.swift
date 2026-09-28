import Foundation
import Jev

/// Connects to sim-use and Jev and works toward a session's goal, saving the session after the run.
package struct RunGoalRunner: Sendable {
    private let bootstrap: SimUseBootstrap
    private let configStore: UserConfigStore
    private let sessionStore: SessionStore
    private let environment: [String: String]
    private let now: @Sendable () -> Date
    private let makeSessionID: @Sendable () -> String
    private let makePlanner: @Sendable (JevSettings) -> any StepPlanning
    private let screenWatch: (any ScreenWatchOpening)?

    package init(
        bootstrap: SimUseBootstrap,
        configStore: UserConfigStore,
        sessionStore: SessionStore,
        environment: [String: String],
        now: @escaping @Sendable () -> Date = { Date() },
        makeSessionID: @escaping @Sendable () -> String = { String(UUID().uuidString.prefix(8)).lowercased() },
        makePlanner: @escaping @Sendable (JevSettings) -> any StepPlanning = { JevStepPlanner(client: $0.makeClient()) },
        screenWatch: (any ScreenWatchOpening)? = nil,
    ) {
        self.bootstrap = bootstrap
        self.configStore = configStore
        self.sessionStore = sessionStore
        self.environment = environment
        self.now = now
        self.makeSessionID = makeSessionID
        self.makePlanner = makePlanner
        self.screenWatch = screenWatch
    }

    /// Resolves settings, pins the device, and runs the agent loop until it stops.
    ///
    /// A resumed session continues its history with its notes, and gets a fresh `maxSteps` budget. The session is
    /// deleted once the goal is reached; expired sessions are removed first.
    package func run(
        _ request: RunGoalRequest,
        report: @escaping @Sendable (RunGoalEvent) -> Void,
    ) async throws -> RunGoalOutcome {
        let settings = try JevSettings.resolve(
            baseURLFlag: request.baseURL, modelFlag: request.model, config: configStore.load(), environment: environment,
        )
        SkillVersionCheck(environment: environment).warnings().forEach { report(.warning($0)) }
        try sessionStore.removeExpired(now: now())
        let (loaded, resumed) = switch request.session {
        case let .new(goal, texts): (SessionRecord(id: makeSessionID(), goal: goal, texts: texts, updatedAt: now()), false)
        case let .resume(id): try (sessionStore.load(id), true)
        }
        var session = loaded
        let connection = try await bootstrap.connect(
            deviceID: SimUseBootstrap.deviceID(flag: request.deviceID ?? session.deviceID, environment: environment),
            onDaemonRecovery: { report(.warning($0.description)) },
        )
        connection.versionWarning.map { report(.warning($0)) }
        report(.connected(device: connection.client.device, endpoint: settings.endpoint))

        session.deviceID = connection.client.device.deviceId
        try sessionStore.save(session)
        report(.session(id: session.id, resumed: resumed))
        let screen = await screenWatcher(for: connection.client.device, report: report)
        defer { screen?.close() }

        let result = try await AgentLoop(
            driver: connection.client,
            planner: makePlanner(settings),
            configuration: AgentConfiguration(
                goal: session.goal, texts: session.texts, notes: session.notes, maxSteps: request.maxSteps,
                actionPolicy: ActionPolicy(minimumSupport: request.minConfidence),
                allowedOperations: request.allowedOperations,
                unchangedWait: AgentLoop.unchangedWait, waitDuration: AgentLoop.waitDuration,
                handOverWait: AgentLoop.handOverWait, stepTimeout: request.stepTimeout,
                minUnchangedReads: AgentLoop.minUnchangedReads, minHandOverReads: AgentLoop.minHandOverReads,
                quietPeriod: AgentLoop.quietPeriod, settleWait: AgentLoop.settleWait, maxWait: AgentLoop.maxWait,
            ),
            screen: screen,
            report: { report(.agent($0)) },
        ).run(continuing: session.history)

        if result.outcome.isSuccess {
            try sessionStore.delete(session.id)
        } else {
            let ended = now()
            let steps = result.history.count - session.history.count
            session.runs.append(SessionRun(endedAt: ended, steps: steps, outcome: result.outcome.description, timing: result.timing))
            session.history = result.history
            session.updatedAt = ended
            try sessionStore.save(session)
        }
        return RunGoalOutcome(sessionID: session.id, outcome: result.outcome)
    }

    /// A watcher on the pinned simulator's screen, or `nil` after one debug note when there is none: the loop then
    /// reads by polling, as it always did.
    private func screenWatcher(
        for device: SimUseDevice, report: @Sendable (RunGoalEvent) -> Void,
    ) async -> (any ClosableScreenWatcher)? {
        guard let screenWatch else { return nil }
        do throws(ScreenWatchError) {
            guard device.platform == SimUseContract.Platform.ios, device.kind == "simulator" else {
                throw .notASimulator(device.deviceId)
            }
            return try await screenWatch.open(simulatorID: device.deviceId)
        } catch {
            report(.debug("no screen-change watcher (\(error)); reading the screen by polling"))
            return nil
        }
    }
}

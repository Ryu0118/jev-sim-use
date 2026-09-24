import Foundation
@testable import JevSimUseKit
import Synchronization
import Testing

struct RunGoalRunnerTests {
    private let request = RunGoalRequest(
        goal: "Open Settings", texts: [], maxSteps: 3, minConfidence: 0.6, deviceID: nil, baseURL: nil, model: nil,
    )

    private func runner(version: String = "v0.14.0") throws -> RunGoalRunner {
        let commands = FakeCommandRunner([
            "--version": .text(version),
            "devices": .json(Fixtures.devices(Fixtures.simulator)),
            "ui": .json(#"{"ok":true,"data":{"platform":"ios","outline":"App: SpringBoard","entries":[]}}"#),
        ])
        let environment = [JevSettings.apiKeyVariable: "k", "XDG_CONFIG_HOME": NSTemporaryDirectory()]
        return try RunGoalRunner(
            bootstrap: SimUseBootstrap(
                locator: ExecutableLocator(environment: ["PATH": TemporaryPath().withExecutable("sim-use")]),
                runner: commands,
            ),
            configStore: UserConfigStore(environment: environment),
            environment: environment,
            makePlanner: { _ in FakePlanner([.tapNext(goal: 0.95)]) },
        )
    }

    @Test("reports the pinned device and endpoint, then runs the loop")
    func reachesGoal() async throws {
        let events = Mutex<[RunGoalEvent]>([])
        let outcome = try await runner().run(request) { event in events.withLock { $0.append(event) } }
        #expect(outcome == .goalReached(steps: 0))
        let first = try #require(events.withLock { $0.first })
        #expect(first.description.hasPrefix("Device: iPhone 17 Pro"))
    }

    @Test("warns when sim-use is newer than the tested version")
    func untestedVersion() async throws {
        let events = Mutex<[RunGoalEvent]>([])
        _ = try await runner(version: "v0.15.0").run(request) { event in events.withLock { $0.append(event) } }
        #expect(events.withLock { $0.contains { $0.description.hasPrefix("Warning: sim-use 0.15.0") } })
    }

    @Test("never acts without confirmation below the default auto threshold", arguments: [0.3, 0.9])
    func policy(minConfidence: Double) {
        let policy = RunGoalRunner.policy(minConfidence: minConfidence)
        #expect(policy.escalateBelow == minConfidence)
        #expect(policy.autoAtOrAbove == max(minConfidence, 0.85))
    }
}

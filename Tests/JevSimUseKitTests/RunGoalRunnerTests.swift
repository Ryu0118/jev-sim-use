import Foundation
@testable import JevSimUseKit
import Synchronization
import Testing

struct RunGoalRunnerTests {
    private let environment = [
        JevSettings.apiKeyVariable: "k",
        "XDG_CONFIG_HOME": NSTemporaryDirectory(),
        "XDG_STATE_HOME": FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).path(),
    ]

    private func request(_ session: SessionStart = .new(goal: "Open Settings", texts: [])) -> RunGoalRequest {
        RunGoalRequest(session: session, maxSteps: 3, minConfidence: 0.6, deviceID: nil, baseURL: nil, model: nil)
    }

    private func runner(version: String = "v0.14.0", plans: [StepPlan] = [.tapNext(goal: 0.95)]) throws -> RunGoalRunner {
        let commands = FakeCommandRunner([
            "--version": .text(version),
            "devices": .json(Fixtures.devices(Fixtures.simulator)),
            "ui": .json(#"{"ok":true,"data":{"platform":"ios","outline":"App: SpringBoard","entries":[]}}"#),
        ])
        return try RunGoalRunner(
            bootstrap: SimUseBootstrap(
                locator: ExecutableLocator(environment: ["PATH": TemporaryPath().withExecutable("sim-use")]),
                runner: commands,
            ),
            configStore: UserConfigStore(environment: environment),
            sessionStore: SessionStore(environment: environment),
            environment: environment,
            makeSessionID: { "s1" },
            makePlanner: { _ in FakePlanner(plans) },
        )
    }

    @Test("reports the pinned device and endpoint, then runs the loop in a new session")
    func reachesGoal() async throws {
        let events = Mutex<[RunGoalEvent]>([])
        let result = try await runner().run(request()) { event in events.withLock { $0.append(event) } }
        #expect(result == RunGoalOutcome(sessionID: "s1", outcome: .goalReached(steps: 0)))
        let first = try #require(events.withLock { $0.first })
        #expect(first.description.hasPrefix("Device: iPhone 17 Pro"))
        #expect(events.withLock { $0.contains(.session(id: "s1", resumed: false)) })
        #expect(try SessionStore(environment: environment).list().isEmpty)
    }

    @Test("saves the session with its device, history, and run outcome")
    func savesSession() async throws {
        _ = try await runner(plans: [.tapNext(confidence: 0.3)]).run(request()) { _ in }
        let session = try SessionStore(environment: environment).load("s1")
        #expect(session.goal == "Open Settings")
        #expect(session.deviceID == "B34F0000-0000-0000-0000-000000000001")
        #expect(session.runs.count == 1)
    }

    @Test("resuming continues the latest session, which is deleted once the goal is reached")
    func resumes() async throws {
        let store = SessionStore(environment: environment)
        var session = SessionRecord(id: "old", goal: "Turn on dark mode", texts: [], updatedAt: Date())
        session.notes = ["The toggle is under Developer."]
        session.history = [HistoryEntry(step: 1, action: "Scroll down", screenChanged: true)]
        try store.save(session)
        let events = Mutex<[RunGoalEvent]>([])
        let result = try await runner().run(request(.resume(id: nil))) { event in events.withLock { $0.append(event) } }
        #expect(result.sessionID == "old")
        #expect(events.withLock { $0.contains(.session(id: "old", resumed: true)) })
        #expect(throws: SessionStoreError.notFound(id: "old")) { try store.load("old") }
    }

    @Test("warns when sim-use is newer than the tested version")
    func untestedVersion() async throws {
        let events = Mutex<[RunGoalEvent]>([])
        _ = try await runner(version: "v0.15.0").run(request()) { event in events.withLock { $0.append(event) } }
        #expect(events.withLock { $0.contains { $0.description.hasPrefix("Warning: sim-use 0.15.0") } })
    }
}

@Suite("The progress line names the session and says it goes away on success")
struct RunGoalEventSessionTests {
    @Test("new and resumed sessions both say they are deleted when the goal is reached")
    func sessionLine() {
        #expect(RunGoalEvent.session(id: "s1", resumed: false).description == "Session: s1 (deleted when the goal is reached)")
        #expect(RunGoalEvent.session(id: "s1", resumed: true).description == "Resuming session s1 (deleted when the goal is reached)")
    }
}

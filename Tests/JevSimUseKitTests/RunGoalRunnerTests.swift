import Foundation
@testable import JevSimUseKit
import Synchronization
import Testing

/// A session must survive a run that stops short (it is what `resume` continues) and be deleted once the goal is
/// reached.
struct RunGoalRunnerTests {
    private let environment = [
        JevSettings.apiKeyVariable: "k",
        "XDG_CONFIG_HOME": NSTemporaryDirectory(),
        "XDG_STATE_HOME": FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).path(),
    ]

    private func request(_ session: SessionStart = .new(goal: "Open Settings", texts: [])) -> RunGoalRequest {
        RunGoalRequest(session: session, maxSteps: 3, minConfidence: 0.6, deviceID: nil, baseURL: nil, model: nil)
    }

    private func runner(version: String = "v0.14.0", plans: [StepPlan] = [.done()]) throws -> RunGoalRunner {
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

    @Test("saves the session with its device, history, and run outcome")
    func savesSession() async throws {
        let unsurePaste = StepPlan(
            action: .enterText(field: 1, label: "Name", text: InputText(name: "text", value: "x")), confidence: 0.3, costUSD: 0,
        )
        _ = try await runner(plans: [unsurePaste]).run(request()) { _ in }
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
}

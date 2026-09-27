import Foundation
@testable import JevSimUseKit
import Synchronization
import Testing

/// The run owns the watcher: it must watch the device the run is pinned to, stop watching however the run ends, and
/// fall back to polling with one debug note when no watcher can be opened.
@Suite("A run watches its pinned simulator's screen and closes the watcher when it ends")
struct ScreenWatchRunnerTests {
    private let environment = [
        "HOME": FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).path(),
        JevSettings.apiKeyVariable: "k",
        "XDG_CONFIG_HOME": NSTemporaryDirectory(),
        "XDG_STATE_HOME": FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).path(),
    ]

    private func run(
        device: String = Fixtures.simulator, opener: RecordingScreenWatchOpener, planner: any StepPlanning = FakePlanner([.done()]),
    ) async throws -> [RunGoalEvent] {
        let commands = FakeCommandRunner([
            "--version": .text("v0.14.0"),
            "devices": .json(Fixtures.devices(device)),
            "ui": .json(#"{"ok":true,"data":{"platform":"ios","outline":"App: SpringBoard","entries":[]}}"#),
        ])
        let runner = try RunGoalRunner(
            bootstrap: SimUseBootstrap(
                locator: ExecutableLocator(environment: ["PATH": TemporaryPath().withExecutable("sim-use")]), runner: commands,
            ),
            configStore: UserConfigStore(environment: environment),
            sessionStore: SessionStore(environment: environment),
            environment: environment,
            makeSessionID: { "s1" },
            makePlanner: { _ in planner },
            screenWatch: opener,
        )
        let events = Mutex<[RunGoalEvent]>([])
        _ = try await runner.run(
            RunGoalRequest(
                session: .new(goal: "Open Settings", texts: []), maxSteps: 3, minConfidence: 0.6, deviceID: nil, baseURL: nil,
                model: nil,
            ),
        ) { event in events.withLock { $0.append(event) } }
        return events.withLock { $0 }
    }

    private static func debugNotes(_ events: [RunGoalEvent]) -> [String] {
        events.compactMap {
            if case let .debug(note) = $0 {
                note
            } else {
                nil
            }
        }
    }

    @Test("opens the watcher for the simulator the run is pinned to and closes it once the run ends")
    func pinnedAndClosed() async throws {
        let opener = RecordingScreenWatchOpener()
        _ = try await run(opener: opener)
        #expect(opener.openedIDs == [Fixtures.device(Fixtures.simulator).deviceId])
        #expect(opener.watcher.closes == 1)
    }

    @Test("closes the watcher when the run throws")
    func closedOnThrow() async throws {
        let opener = RecordingScreenWatchOpener()
        await #expect(throws: PlanningError.missingChoice) {
            try await run(opener: opener, planner: ThrowingPlanner())
        }
        #expect(opener.watcher.closes == 1)
    }

    @Test("does not look for a simulator display on an Android device")
    func androidNotWatched() async throws {
        let opener = RecordingScreenWatchOpener()
        let events = try await run(device: Fixtures.emulator, opener: opener)
        #expect(opener.openedIDs.isEmpty)
        #expect(Self.debugNotes(events).count == 1)
    }

    @Test("runs by polling after one debug note, and no warning, when the watcher cannot be opened")
    func fallsBackQuietly() async throws {
        let opener = RecordingScreenWatchOpener(failure: .selectorMissing("framebufferSurface"))
        let events = try await run(opener: opener)
        let notes = Self.debugNotes(events)
        #expect(notes.count == 1)
        #expect(notes.first?.contains("framebufferSurface") == true)
        #expect(!events.contains {
            if case .warning = $0 {
                true
            } else {
                false
            }
        })
    }
}

private struct ThrowingPlanner: StepPlanning {
    func plan(_: PlanRequest) async throws -> StepPlan {
        throw PlanningError.missingChoice
    }
}

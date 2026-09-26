import Jev
@testable import JevSimUseKit
import Synchronization
import Testing

/// Real-run regressions the loop must not return to: a tap repeated on a screen it did not change, a back swipe a map
/// swallowed, a false DONE (below the bar, or claimed from the expectation that an action would finish the goal), a
/// Home press at 0.66 that left the app, and a crash going unnoticed.
struct AgentLoopTests {
    private func run(_ driver: FakeDriver, _ plans: [StepPlan], maxSteps: Int = 5) async throws -> AgentOutcome {
        try await AgentLoop(
            driver: driver,
            planner: FakePlanner(plans),
            configuration: AgentConfiguration(goal: "Finish onboarding", maxSteps: maxSteps),
        ).run().outcome
    }

    @Test("types a text again over a field that already holds exactly it, instead of appending a second copy")
    func retypeReplaces() async throws {
        let title = InputText(name: "title", value: "Team sync")
        let driver = FakeDriver(outlines: ["A", "B"], entries: [Fixtures.entry(1, "Team sync", role: "TextField", value: "Team sync")])
        _ = try await run(driver, [StepPlan(action: .enterText(field: 1, label: "Title", text: title), confidence: 0.9, costUSD: 0), .done()])
        #expect(driver.performedActions == ["tap @1", "paste --replace Team sync"])
    }

    @Test("hands over instead of repeating an action that did not change the screen")
    func noRepeat() async throws {
        let driver = FakeDriver(outlines: ["A"])
        let outcome = try await run(driver, [.tapNext()], maxSteps: 10)
        #expect(outcome == .noActionFits(step: 2))
        #expect(driver.performedActions == ["tap @1"])
    }

    @Test("goes back on iOS by tapping the back button, which a map on the screen cannot swallow like the edge swipe")
    func goBackTapsBackButton() async throws {
        let back = UIEntry(
            aliases: ElementAliases(alias: 7), role: "Button", label: "History", states: [], value: nil,
            uniqueId: "BackButton", region: nil, frame: nil,
        )
        let driver = FakeDriver(outlines: ["Detail", "History"], entries: [back])
        let plan = StepPlan(action: .device(.goBack), confidence: 0.9, costUSD: 0)
        _ = try await run(driver, [plan, .done()])
        #expect(driver.performedActions == ["tap @7"])
    }

    @Test("stops when the app disappears after an action")
    func appDisappears() async throws {
        let driver = FakeDriver(outlines: ["A", "B"], disappearedAfterEachAction: ["com.example.app"])
        let outcome = try await run(driver, [.tapNext()])
        #expect(outcome == .appCrashed(detail: "the app disappeared (com.example.app)."))
    }

    @Test("a DONE below the bar stops as probably reached, not as success")
    func unsureDone() async throws {
        let driver = FakeDriver(outlines: ["A"])
        #expect(try await run(driver, [.done(confidence: 0.4)]) == .goalProbablyReached(steps: 0, probability: 0.4))
        #expect(driver.performedActions.isEmpty)
    }

    @Test("asks Jev to judge the screen after an action it expected to finish the goal")
    func judgesAfterExpectedFinish() async throws {
        let title = Fixtures.entry(0, "Home", role: "Heading")
        let form = Fixtures.snapshot(outline: "A", entries: [title, Fixtures.entry(1, "Next")])
        let scrolled = Fixtures.snapshot(outline: "A scrolled", entries: [title, Fixtures.entry(2, "Other")])
        let driver = ScriptedDriver(readings: [form, form, scrolled])
        let planner = FakePlanner([.tapNext(finishes: 0.9), .blocked()])
        let outcome = try await AgentLoop(driver: driver, planner: planner, configuration: AgentConfiguration(goal: "g")).run()
        #expect(outcome.outcome == .noActionFits(step: 2))
    }

    @Test("hands over leaving the app on support that would be enough for a tap")
    func leavingNeedsMoreSupport() async throws {
        let home = AgentAction.device(.press(.home))
        let driver = FakeDriver(outlines: ["A"])
        #expect(try await run(driver, [StepPlan(action: home, confidence: 0.58, costUSD: 0)])
            == .escalated(step: 1, action: home, confidence: 0.58))
        #expect(driver.performedActions.isEmpty)
    }
}

@Suite("A resumed loop gets a fresh step budget and returns the combined history")
struct AgentLoopResumeTests {
    @Test("a run continued after the step limit can act again")
    func freshBudget() async throws {
        let earlier = (1 ... 2).map { HistoryEntry(step: $0, action: "Tap e1", screenChanged: true) }
        let result = try await AgentLoop(
            driver: FakeDriver(outlines: ["A", "B", "C"]),
            planner: FakePlanner([.tapNext(), .done()]),
            configuration: AgentConfiguration(goal: "Finish onboarding", maxSteps: 2),
        ).run(continuing: earlier)
        #expect(result.outcome == .goalReached(steps: 1))
        #expect(result.history.map(\.step) == [1, 2, 3])
    }
}

@Suite("A gesture that did nothing on a screen is not repeated there")
struct AgentLoopGestureTests {
    @Test("hands over instead of long-pressing the same element on the same screen again")
    func repeatedGesture() async throws {
        let longPress = StepPlan(action: .gesture(.longPress, alias: 1, role: "Button", label: "Next"), confidence: 0.9, costUSD: 0)
        let driver = FakeDriver(outlines: ["A"])
        _ = try await AgentLoop(
            driver: driver, planner: FakePlanner([longPress]), configuration: AgentConfiguration(goal: "g", maxSteps: 3),
        ).run()
        #expect(driver.performedActions.first == "long_press @1")
        #expect(driver.performedActions.dropFirst().allSatisfy { !$0.hasPrefix("long_press") })
    }
}

/// Unsure on the first screen it sees, done on the next; records the screens it planned on.
private final class UnsureThenDonePlanner: StepPlanning {
    private let seen = Mutex<[String]>([])

    var outlines: [String] {
        seen.withLock { $0 }
    }

    func plan(_ request: PlanRequest) async throws -> StepPlan {
        let count = seen.withLock { $0.append(request.snapshot.outline); return $0.count }
        return count == 1 ? .tapNext(confidence: 0.3) : .done()
    }
}

/// Taps `taps` times, then hands over, recording the screen each plan was made on.
private final class TapOncePlanner: StepPlanning {
    private let seen = Mutex<[String]>([])
    private let taps: Int

    init(taps: Int = 1) {
        self.taps = taps
    }

    var outlines: [String] {
        seen.withLock { $0 }
    }

    func plan(_ request: PlanRequest) async throws -> StepPlan {
        let count = seen.withLock { $0.append(request.snapshot.outline); return $0.count }
        guard count <= taps else { return .blocked() }
        // A different target each time: repeating a tap that did nothing on a screen is refused before acting.
        return StepPlan(action: .tap(alias: count, role: "Button", label: "Button \(count)"), confidence: 0.9, costUSD: 0)
    }
}

/// Acting, stopping, handing over, resuming, and not repeating a tap that did nothing run end to end in
/// scripts/e2e.sh, where the fake screen changes at once. These are the ways a real screen still moving can mislead
/// the loop, each from a real run.
@Suite("Plans are made on a settled screen, not one still mid-transition")
struct AgentLoopSettleTests {
    @Test("keeps reading after an action that has not changed the screen yet, as a save still in flight")
    func waitsForSlowChange() async throws {
        let outlines = ["Form", "Form", "Form", "Form", "Form", "Home", "Home"]
        let waiting = TapOncePlanner()
        _ = try await AgentLoop(
            driver: ScriptedDriver(outlines: outlines), planner: waiting,
            configuration: AgentConfiguration(goal: "g", unchangedWait: .milliseconds(1200)),
        ).run()
        #expect(waiting.outlines == ["Form", "Home", "Home"])
        let hasty = TapOncePlanner()
        _ = try await AgentLoop(
            driver: ScriptedDriver(outlines: outlines), planner: hasty, configuration: AgentConfiguration(goal: "g"),
        ).run()
        #expect(hasty.outlines == ["Form", "Form", "Form"])
    }

    @Test("plans again instead of handing over when the screen moved on while Jev decided to stop")
    func replansStaleHandOver() async throws {
        let planner = UnsureThenDonePlanner()
        let outcome = try await AgentLoop(
            driver: ScriptedDriver(outlines: ["Saving", "Saving", "Home", "Home", "Home"]), planner: planner,
            configuration: AgentConfiguration(goal: "g"),
        ).run().outcome
        #expect(planner.outlines == ["Saving", "Home"])
        #expect(outcome == .goalReached(steps: 0))
    }

    @Test("drops a plan whose screen changed while Jev decided, after an action that had not shown its effect")
    func freshness() async throws {
        let planner = TapOncePlanner(taps: 2)
        _ = try await AgentLoop(
            driver: ScriptedDriver(outlines: ["Form", "Form", "Form", "Form", "Home", "Home", "Home"]), planner: planner,
            configuration: AgentConfiguration(goal: "g"),
        ).run()
        #expect(planner.outlines == ["Form", "Form", "Home", "Home"])
    }

    @Test("plans a hand-over again on the confirming reading when that reading shows a newer screen")
    func settles() async throws {
        let planner = RecordingPlanner()
        _ = try await AgentLoop(
            driver: ScriptedDriver(outlines: ["Old", "New", "New"]),
            planner: planner,
            configuration: AgentConfiguration(goal: "g"),
        ).run()
        #expect(planner.outlines == ["Old", "New", "New"])
    }
}

import Jev
@testable import JevSimUseKit
import Testing

struct AgentLoopTests {
    private func run(_ driver: FakeDriver, _ plans: [StepPlan], maxSteps: Int = 5) async throws -> AgentOutcome {
        try await AgentLoop(
            driver: driver,
            planner: FakePlanner(plans),
            configuration: AgentConfiguration(goal: "Finish onboarding", maxSteps: maxSteps),
        ).run().outcome
    }

    @Test("acts until Jev chooses DONE")
    func reachesGoal() async throws {
        let driver = FakeDriver(outlines: ["A", "B", "C"])
        let outcome = try await run(driver, [.tapNext(), .tapNext(), .done()])
        #expect(outcome == .goalReached(steps: 2))
        #expect(driver.performedActions == ["tap @1", "tap @1"])
    }

    @Test("hands over an unsure tap without acting or exploring")
    func escalates() async throws {
        let driver = FakeDriver(outlines: ["A"])
        let outcome = try await run(driver, [.tapNext(confidence: 0.3)])
        #expect(outcome == .escalated(step: 1, action: .tap(alias: 1, role: "Button", label: "Next"), confidence: 0.3))
        #expect(driver.performedActions.isEmpty)
    }

    @Test("hands over instead of repeating an action that did not change the screen")
    func noRepeat() async throws {
        let driver = FakeDriver(outlines: ["A"])
        let outcome = try await run(driver, [.tapNext()], maxSteps: 10)
        #expect(outcome == .noActionFits(step: 2))
        #expect(driver.performedActions == ["tap @1"])
    }

    @Test("stops at the step limit")
    func stepLimit() async throws {
        let outcome = try await run(FakeDriver(outlines: ["A", "B", "C", "D"]), [.tapNext()], maxSteps: 2)
        #expect(outcome == .stepLimitReached(steps: 2))
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

    @Test("finishes without asking again when Jev expected the action to finish and the screen changed")
    func earlyFinish() async throws {
        let driver = FakeDriver(outlines: ["A", "B"])
        let planner = FakePlanner([.tapNext(finishes: 0.9), .blocked()])
        let outcome = try await AgentLoop(driver: driver, planner: planner, configuration: AgentConfiguration(goal: "g")).run()
        #expect(outcome.outcome == .goalReached(steps: 1))
    }

    @Test("hands over at once when nothing fits")
    func noActionFits() async throws {
        let driver = FakeDriver(outlines: ["A"])
        #expect(try await run(driver, [.blocked()]) == .noActionFits(step: 1))
        #expect(driver.performedActions.isEmpty)
    }

    @Test("enters text on the support a tap needs, since text in a field can be cleared")
    func textOnTapSupport() async throws {
        let enter = AgentAction.enterText(field: 1, label: "Name", text: InputText(name: "name", value: "hi"))
        let driver = FakeDriver(outlines: ["A", "B"])
        #expect(try await run(driver, [StepPlan(action: enter, confidence: 0.7, costUSD: 0), .done()])
            == .goalReached(steps: 1))
        #expect(driver.performedActions == ["tap @1", "paste hi"])
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

@Suite("Plans are made on a settled screen, not one still mid-transition")
struct AgentLoopSettleTests {
    @Test("reads again until two readings agree")
    func settles() async throws {
        let planner = RecordingPlanner()
        _ = try await AgentLoop(
            driver: ScriptedDriver(outlines: ["Old", "New", "New"]),
            planner: planner,
            configuration: AgentConfiguration(goal: "g"),
        ).run()
        #expect(planner.outlines.first == "New")
    }
}

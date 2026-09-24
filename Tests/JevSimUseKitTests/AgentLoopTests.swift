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

    @Test("acts until Jev judges the goal reached")
    func reachesGoal() async throws {
        let driver = FakeDriver(outlines: ["A", "B", "C"])
        let outcome = try await run(driver, [.tapNext(), .tapNext(), .tapNext(goal: 0.95)])
        #expect(outcome == .goalReached(steps: 2))
        #expect(driver.performedActions == ["tap @1", "tap @1"])
    }

    @Test("stops without acting when confidence is below the threshold")
    func escalates() async throws {
        let driver = FakeDriver(outlines: ["A"])
        let outcome = try await run(driver, [.tapNext(confidence: 0.3)])
        #expect(outcome == .escalated(step: 1, action: .tap(alias: 1, role: "Button", label: "Next"), confidence: 0.3))
        #expect(driver.performedActions.isEmpty)
    }

    @Test("stops when actions stop changing the screen")
    func stalls() async throws {
        let outcome = try await run(FakeDriver(outlines: ["A"]), [.tapNext()], maxSteps: 10)
        #expect(outcome == .stalled(steps: 3))
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

    @Test("keeps acting while the goal is only moderately likely")
    func moderateGoalIsNotSuccess() async throws {
        let driver = FakeDriver(outlines: ["A", "B", "C"])
        let outcome = try await run(driver, [.tapNext(goal: 0.7), .tapNext(goal: 0.9)])
        #expect(outcome == .goalReached(steps: 1))
    }

    @Test("explores down, then back, before handing over when nothing fits")
    func noActionFits() async throws {
        let plan = StepPlan(goalReached: Probability(clamping: 0.05), action: .noneApplies, confidence: 0.9, costUSD: 0)
        let driver = FakeDriver(outlines: ["A"])
        #expect(try await run(driver, [plan]) == .noActionFits(step: 3))
        #expect(driver.performedActions == ["revealContentBelow", "goBack"])
    }

    @Test("will not paste on support that would be enough for a tap")
    func pasteNeedsMoreSupport() async throws {
        let plan = StepPlan(
            goalReached: Probability(clamping: 0.05), action: .paste(index: 0, text: "hi"), confidence: 0.7, costUSD: 0,
        )
        let driver = FakeDriver(outlines: ["A"])
        #expect(try await run(driver, [plan]) == .escalated(step: 1, action: .paste(index: 0, text: "hi"), confidence: 0.7))
    }
}

@Suite("A resumed loop gets a fresh step budget and returns the combined history")
struct AgentLoopResumeTests {
    @Test("a run continued after the step limit can act again")
    func freshBudget() async throws {
        let earlier = (1 ... 2).map { HistoryEntry(step: $0, action: "Tap e1", screenChanged: true) }
        let result = try await AgentLoop(
            driver: FakeDriver(outlines: ["A", "B", "C"]),
            planner: FakePlanner([.tapNext(), .tapNext(goal: 0.95)]),
            configuration: AgentConfiguration(goal: "Finish onboarding", maxSteps: 2),
        ).run(continuing: earlier)
        #expect(result.outcome == .goalReached(steps: 1))
        #expect(result.history.map(\.step) == [1, 2, 3])
    }
}

@Suite("A gesture that did nothing on a screen is not repeated there")
struct AgentLoopGestureTests {
    @Test("explores instead of long-pressing the same element on the same screen again")
    func repeatedGesture() async throws {
        let longPress = StepPlan(
            goalReached: .init(clamping: 0.05), action: .gesture(.longPress, alias: 1, role: "Button", label: "Next"),
            confidence: 0.9, costUSD: 0,
        )
        let driver = FakeDriver(outlines: ["A"])
        _ = try await AgentLoop(
            driver: driver, planner: FakePlanner([longPress]), configuration: AgentConfiguration(goal: "g", maxSteps: 3),
        ).run()
        #expect(driver.performedActions.first == "long_press @1")
        #expect(driver.performedActions.dropFirst().allSatisfy { !$0.hasPrefix("long_press") })
    }
}

@Suite("When Jev leans toward done and has nothing to do, the loop stops instead of exploring away")
struct AgentLoopProbablyDoneTests {
    @Test("stops with goalProbablyReached and takes no exploring action")
    func probablyDone() async throws {
        let plan = StepPlan(goalReached: Probability(clamping: 0.84), action: .noneApplies, confidence: 0.6, costUSD: 0)
        let driver = FakeDriver(outlines: ["A"])
        let outcome = try await AgentLoop(
            driver: driver, planner: FakePlanner([plan]), configuration: AgentConfiguration(goal: "g"),
        ).run().outcome
        #expect(outcome == .goalProbablyReached(steps: 0, probability: Probability(clamping: 0.84).value))
        #expect(driver.performedActions.isEmpty)
    }
}

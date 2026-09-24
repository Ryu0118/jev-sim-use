import Jev
@testable import JevSimUseKit
import Testing

struct AgentLoopTests {
    private func run(_ driver: FakeDriver, _ plans: [StepPlan], maxSteps: Int = 5) async throws -> AgentOutcome {
        try await AgentLoop(
            driver: driver,
            planner: FakePlanner(plans),
            configuration: AgentConfiguration(goal: "Finish onboarding", maxSteps: maxSteps),
        ).run()
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

    @Test("hands over when Jev says no offered action fits")
    func noActionFits() async throws {
        let plan = StepPlan(goalReached: Probability(clamping: 0.05), action: .noneApplies, confidence: 0.9, costUSD: 0)
        let driver = FakeDriver(outlines: ["A"])
        #expect(try await run(driver, [plan]) == .noActionFits(step: 1))
        #expect(driver.performedActions.isEmpty)
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

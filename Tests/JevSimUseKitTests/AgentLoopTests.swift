import Jev
@testable import JevSimUseKit
import Synchronization
import Testing

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
        #expect(waiting.outlines == ["Form", "Home"])
        let hasty = TapOncePlanner()
        _ = try await AgentLoop(
            driver: ScriptedDriver(outlines: outlines), planner: hasty, configuration: AgentConfiguration(goal: "g"),
        ).run()
        #expect(hasty.outlines == ["Form", "Form"])
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
        #expect(planner.outlines == ["Form", "Form", "Home"])
    }

    @Test("plans a hand-over again on the confirming reading when that reading shows a newer screen")
    func settles() async throws {
        let planner = RecordingPlanner()
        _ = try await AgentLoop(
            driver: ScriptedDriver(outlines: ["Old", "New", "New"]),
            planner: planner,
            configuration: AgentConfiguration(goal: "g"),
        ).run()
        #expect(planner.outlines == ["Old", "New"])
    }
}

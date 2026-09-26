@testable import JevSimUseKit
import Synchronization
import Testing

/// Ways the loop's step-to-step bookkeeping can break without any single reading or plan looking wrong. Written before
/// the loop was restructured, each passing on the code as it was.
@Suite("The loop keeps its counters, pending reading, and confirming read straight across steps")
struct AgentLoopTransitionTests {
    @Test("plans a hand-over again at most twice per step when the screen keeps moving on")
    func staleReplanLimit() async throws {
        let planner = RecordingPlanner()
        let driver = ScriptedDriver(outlines: ["A", "A", "B", "B", "C", "C", "D", "D"])
        let outcome = try await AgentLoop(driver: driver, planner: planner, configuration: AgentConfiguration(goal: "g"))
            .run().outcome
        #expect(planner.outlines == ["A", "B", "C"])
        #expect(outcome == .noActionFits(step: 1))
    }

    @Test("cancels the confirming read when planning fails")
    func cancelsConfirmation() async {
        let driver = SlowSecondReadDriver()
        await #expect(throws: PlanningError.missingChoice) {
            try await AgentLoop(driver: driver, planner: FailingPlanner(), configuration: AgentConfiguration(goal: "g")).run()
        }
        await driver.waitForSecondRead()
        #expect(driver.secondReadCancelled)
    }

    @Test("does not scroll for the goal's named item until the confirming reading agrees with the planned one")
    func scanWaitsForSettledScreen() async throws {
        /// A list still scrolling: the second reading shows one more row, so neither its layout nor its identity agree.
        func list(_ rows: Int) -> UISnapshot {
            let entries = ["一般", "カメラ", "検索", "アプリ", "壁紙"].prefix(rows).enumerated().map { index, label in
                Fixtures.entry(index + 1, label, frame: ElementFrame(x: 16, y: 120 + Double(index * 52), width: 370, height: 52))
            }
            return UISnapshot(platform: "ios", outline: "\(rows) rows", appLabel: "設定", entries: entries, crashDialog: nil)
        }
        let unsure = StepPlan(action: .tap(alias: 1, role: "Button", label: "一般"), confidence: 0.6, costUSD: 0)
        let driver = ScriptedDriver(readings: [list(4), list(5), list(5), list(4)])
        let planner = ActionCountingPlanner(driver: driver, plans: [unsure, unsure, .blocked()])
        _ = try await AgentLoop(
            driver: driver, planner: planner, configuration: AgentConfiguration(goal: "Open the デベロッパ screen"),
        ).run()
        #expect(planner.actionsBeforeEachPlan.prefix(3) == [0, 0, 1], "the scroll waits for the second, settled plan")
        #expect(driver.performedActions.first == "revealContentBelow")
    }

    @Test("counts an app that disappeared in the late confirming reading of a stable bar tap")
    func lateConfirmationCrash() async throws {
        let tab = Fixtures.entry(
            5, "Map", role: "RadioButton", frame: ElementFrame(x: 90, y: 795, width: 85, height: 54),
            region: ElementRegion(kind: "Group", label: "Tab Bar"),
        )
        let next = Fixtures.entry(1, "Next", frame: ElementFrame(x: 16, y: 300, width: 370, height: 44))
        let home = Fixtures.snapshot(outline: "Home", entries: [next, tab])
        let detail = Fixtures.snapshot(outline: "Detail", entries: [Fixtures.entry(2, "Detail", role: "Heading"), tab])
        let map = StepPlan(action: .tap(alias: 5, role: "RadioButton", label: "Map"), confidence: 0.95, costUSD: 0)
        let driver = CrashingReadDriver(readings: [home, home, detail, detail], crashingRead: 4)
        let outcome = try await AgentLoop(
            driver: driver, planner: FakePlanner([.tapNext(), map, .blocked()]), configuration: AgentConfiguration(goal: "g"),
        ).run().outcome
        #expect(outcome == .appCrashed(detail: "the app disappeared (com.example.app)."))
    }

    @Test("resets the hand-over re-plans after an action, so the next step may plan again twice")
    func staleReplansResetAfterAction() async throws {
        let planner = OutlinePlanner { $0.outline == "B" ? Self.tapHeading($0) : .blocked() }
        let driver = ScriptedDriver(outlines: ["A", "A", "B", "B", "C", "C", "D", "D", "E", "E", "F", "F"])
        _ = try await AgentLoop(driver: driver, planner: planner, configuration: AgentConfiguration(goal: "g")).run()
        #expect(planner.outlines == ["A", "B", "C", "D", "E"])
    }

    @Test("resets the disagreements after an action, so one more disagreement does not fall back to settled reads")
    func disagreementsResetAfterAction() async throws {
        let planner = OutlinePlanner { $0.outline.hasPrefix("S1") ? Self.tapHeading($0) : .done() }
        let driver = ScriptedDriver(outlines: ["S1a", "S1b", "S1b", "S2a", "S2b", "S2c", "S2c"])
        _ = try await AgentLoop(driver: driver, planner: planner, configuration: AgentConfiguration(goal: "g")).run()
        #expect(planner.outlines == ["S1a", "S1b", "S2a", "S2b", "S2c"])
    }

    @Test("resets the disagreements after a stable bar tap as after any other action")
    func disagreementsResetAfterBarTap() async throws {
        let tab = Fixtures.entry(
            5, "Map", role: "RadioButton", frame: ElementFrame(x: 90, y: 795, width: 85, height: 54),
            region: ElementRegion(kind: "Group", label: "Tab Bar"),
        )
        func screen(_ name: String) -> UISnapshot {
            Fixtures.snapshot(outline: name, entries: [Fixtures.entry(0, name, role: "Heading"), Fixtures.entry(1, "Next"), tab])
        }
        let map = StepPlan(action: .tap(alias: 5, role: "RadioButton", label: "Map"), confidence: 0.95, costUSD: 0)
        let planner = OutlinePlanner { snapshot in
            switch snapshot.outline {
            case "Home": .tapNext()
            case "Detail b": map
            default: .done()
            }
        }
        let driver = ScriptedDriver(readings: [
            "Home", "Home", "Detail a", "Detail b", "Detail b", "Map a", "Map b", "Map c", "Map c",
        ].map(screen))
        _ = try await AgentLoop(driver: driver, planner: planner, configuration: AgentConfiguration(goal: "g")).run()
        #expect(driver.performedActions.prefix(2) == ["tap @1", "tap @5"])
        #expect(planner.outlines == ["Home", "Detail a", "Detail b", "Map a", "Map b", "Map c"])
    }

    @Test("forgets the screen it acted on when a plan's target is gone, so a fallback read does not wait for it to change")
    func actedOnClearedWhenTargetGone() async throws {
        let planner = OutlinePlanner { Self.tapHeading($0) }
        let driver = ScriptedDriver(outlines: ["S1", "S1", "S2a", "S2b", "S2c", "S1", "S1", "S3", "S3"])
        _ = try await AgentLoop(
            driver: driver, planner: planner, configuration: AgentConfiguration(goal: "g", unchangedWait: .seconds(1)),
        ).run()
        #expect(planner.outlines.prefix(4) == ["S1", "S2a", "S2b", "S1"])
    }

    @Test("keeps the hand-over re-plans across the scroll for the goal's named item, which is not the step's action")
    func staleReplansKeptAcrossScan() async throws {
        func list(_ name: String) -> UISnapshot {
            let entries = ["一般", "カメラ", "検索", name].enumerated().map { index, label in
                Fixtures.entry(index + 1, label, frame: ElementFrame(x: 16, y: 120 + Double(index * 52), width: 370, height: 52))
            }
            return UISnapshot(platform: "ios", outline: name, appLabel: "設定", entries: entries, crashDialog: nil)
        }
        let unsure = StepPlan(action: .tap(alias: 1, role: "Button", label: "一般"), confidence: 0.6, costUSD: 0)
        let planner = OutlinePlanner { $0.outline == "B" ? unsure : .blocked() }
        let driver = ScriptedDriver(readings: ["A", "A", "B", "B", "C", "C", "D", "D", "E", "E", "F", "F"].map(list))
        _ = try await AgentLoop(
            driver: driver, planner: planner, configuration: AgentConfiguration(goal: "Open the デベロッパ screen"),
        ).run()
        #expect(driver.performedActions == ["revealContentBelow"])
        #expect(planner.outlines == ["A", "B", "C", "D"])
    }

    /// A tap on the heading that names the screen, so a plan made on one reading misses its target on another.
    private static func tapHeading(_ snapshot: UISnapshot) -> StepPlan {
        StepPlan(action: .tap(alias: 0, role: "Heading", label: snapshot.outline), confidence: 0.9, costUSD: 0)
    }
}

/// Returns plans in order, repeating the last, and records how many actions the driver had performed before each.
private final class ActionCountingPlanner: StepPlanning {
    private let driver: ScriptedDriver
    private let plans: [StepPlan]
    private let counts = Mutex<[Int]>([])

    init(driver: ScriptedDriver, plans: [StepPlan]) {
        self.driver = driver
        self.plans = plans
    }

    var actionsBeforeEachPlan: [Int] {
        counts.withLock { $0 }
    }

    func plan(_: PlanRequest) async throws -> StepPlan {
        let count = counts.withLock { $0.append(driver.performedActions.count); return $0.count }
        return plans[min(count - 1, plans.count - 1)]
    }
}

/// Decides each plan from the planned screen with `decide`, and records the screens planned on.
private final class OutlinePlanner: StepPlanning {
    private let decide: @Sendable (UISnapshot) -> StepPlan
    private let seen = Mutex<[String]>([])

    init(_ decide: @escaping @Sendable (UISnapshot) -> StepPlan) {
        self.decide = decide
    }

    var outlines: [String] {
        seen.withLock { $0 }
    }

    func plan(_ request: PlanRequest) async throws -> StepPlan {
        seen.withLock { $0.append(request.snapshot.outline) }
        return decide(request.snapshot)
    }
}

/// Fails every plan.
private struct FailingPlanner: StepPlanning {
    func plan(_: PlanRequest) async throws -> StepPlan {
        throw PlanningError.missingChoice
    }
}

/// Answers the first read at once and holds the second until it is cancelled or a second passes, recording which.
private final class SlowSecondReadDriver: DeviceDriving {
    private let reads = Mutex(0)
    private let cancelled = Mutex<Bool?>(nil)

    var secondReadCancelled: Bool {
        cancelled.withLock { $0 == true }
    }

    func waitForSecondRead() async {
        while cancelled.withLock({ $0 }) == nil {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func observe() async throws -> ScreenObservation {
        let read = reads.withLock { reads in
            reads += 1
            return reads
        }
        if read == 2 {
            do {
                try await Task.sleep(for: .seconds(1))
                cancelled.withLock { $0 = false }
            } catch {
                cancelled.withLock { $0 = true }
                throw error
            }
        }
        return ScreenObservation(snapshot: Fixtures.snapshot(outline: "A"), disappearedApps: [])
    }

    func tap(alias _: Int, on _: UISnapshot) async throws -> [String] {
        []
    }

    func perform(_: ElementGesture, alias _: Int, on _: UISnapshot) async throws -> [String] {
        []
    }

    func perform(_: SimUseDeviceAction, platform _: String) async throws -> [String] {
        []
    }

    func paste(_: String) async throws -> [String] {
        []
    }
}

/// Returns one reading per `observe` call, in order (repeating the last), and reports the app gone on read
/// `crashingRead` (1-based).
private final class CrashingReadDriver: DeviceDriving {
    private let readings: [UISnapshot]
    private let crashingRead: Int
    private let reads = Mutex(0)

    init(readings: [UISnapshot], crashingRead: Int) {
        self.readings = readings
        self.crashingRead = crashingRead
    }

    func observe() async throws -> ScreenObservation {
        let read = reads.withLock { reads in
            reads += 1
            return reads
        }
        return ScreenObservation(
            snapshot: readings[min(read, readings.count) - 1],
            disappearedApps: read == crashingRead ? ["com.example.app"] : [],
        )
    }

    func tap(alias _: Int, on _: UISnapshot) async throws -> [String] {
        []
    }

    func perform(_: ElementGesture, alias _: Int, on _: UISnapshot) async throws -> [String] {
        []
    }

    func perform(_: SimUseDeviceAction, platform _: String) async throws -> [String] {
        []
    }

    func paste(_: String) async throws -> [String] {
        []
    }
}

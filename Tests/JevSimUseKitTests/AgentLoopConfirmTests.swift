@testable import JevSimUseKit
import Synchronization
import Testing

@Suite("A plan is checked against a reading taken while Jev planned")
struct AgentLoopConfirmTests {
    private func button(_ alias: Int, _ label: String, y: Double) -> UIEntry {
        Fixtures.entry(alias, label, frame: ElementFrame(x: 16, y: y, width: 370, height: 44))
    }

    private func loop(_ readings: [UISnapshot], _ planner: some StepPlanning) -> (AgentLoop, ScriptedDriver) {
        let driver = ScriptedDriver(readings: readings)
        return (AgentLoop(driver: driver, planner: planner, configuration: AgentConfiguration(goal: "g")), driver)
    }

    @Test("does not tap a stale alias when the confirming reading shows the next screen")
    func staleAlias() async throws {
        let planner = TapLabelPlanner("Save")
        let (loop, driver) = loop([
            Fixtures.snapshot(outline: "Form", entries: [button(3, "Save", y: 700)]),
            Fixtures.snapshot(outline: "List", entries: [button(3, "Delete", y: 700)]),
        ], planner)
        _ = try await loop.run()
        #expect(driver.performedActions.isEmpty)
        #expect(planner.outlines == ["Form", "List"])
    }

    @Test("plans again when the target moved between the readings, as in a scroll still coasting")
    func movedTarget() async throws {
        let planner = TapLabelPlanner("Row")
        let (loop, driver) = loop([
            Fixtures.snapshot(outline: "List at 300", entries: [button(5, "Row", y: 300)]),
            Fixtures.snapshot(outline: "List at 260", entries: [button(5, "Row", y: 260)]),
        ], planner)
        _ = try await loop.run()
        #expect(driver.performedActions == ["tap @5"])
        #expect(planner.outlines.prefix(2) == ["List at 300", "List at 260"])
    }

    @Test("taps the unchanged target by its new alias when only something else changed")
    func unrelatedChange() async throws {
        let planner = TapLabelPlanner("Next")
        let clock = Fixtures.entry(1, "10:00", role: "StaticText")
        let (loop, driver) = loop([
            Fixtures.snapshot(outline: "Home 10:00", entries: [clock, button(2, "Next", y: 500)]),
            Fixtures.snapshot(outline: "Home 10:01 banner", entries: [
                Fixtures.entry(1, "10:01", role: "StaticText"), Fixtures.entry(2, "Banner", role: "StaticText"),
                button(3, "Next", y: 500),
            ]),
        ], planner)
        _ = try await loop.run()
        #expect(driver.performedActions == ["tap @3"])
        #expect(planner.outlines.first == "Home 10:00")
        #expect(planner.outlines.dropFirst().allSatisfy { $0 != "Home 10:00" })
    }

    @Test("does not report the goal reached from a reading the confirming one contradicts")
    func doneOnChangingScreen() async throws {
        let planner = RecordingDonePlanner()
        let (loop, _) = loop([
            Fixtures.snapshot(outline: "Mid"), Fixtures.snapshot(outline: "Final"),
        ], planner)
        let outcome = try await loop.run().outcome
        #expect(planner.outlines == ["Mid", "Final"])
        #expect(outcome == .goalReached(steps: 0))
    }

    @Test("accepts DONE when only a value changed between the readings, such as a relative time")
    func tickingValue() async throws {
        let planner = RecordingDonePlanner()
        func row(_ age: String) -> UIEntry {
            UIEntry(
                aliases: ElementAliases(alias: 1), role: "Button", label: "Groceries", states: ["value=\"\(age)\""],
                value: age, uniqueId: nil, region: nil, frame: ElementFrame(x: 16, y: 300, width: 370, height: 44),
            )
        }
        let (loop, _) = loop([
            Fixtures.snapshot(outline: "List 3 s", entries: [row("3 s ago")]),
            Fixtures.snapshot(outline: "List 4 s", entries: [row("4 s ago")]),
        ], planner)
        let outcome = try await loop.run().outcome
        #expect(planner.outlines == ["List 3 s"])
        #expect(outcome == .goalReached(steps: 0))
    }

    @Test("keeps reading for a moment before handing over, as a saved item reaches its list late")
    func lateItem() async throws {
        let planner = DoneWhenShownPlanner("Saved item")
        let driver = ScriptedDriver(readings: ["List", "List", "List", "List", "List with Saved item"].map { outline in
            Fixtures.snapshot(outline: outline, entries: [Fixtures.entry(1, outline, role: "StaticText")])
        })
        let outcome = try await AgentLoop(
            driver: driver, planner: planner,
            configuration: AgentConfiguration(goal: "g", handOverWait: .milliseconds(1200)),
        ).run().outcome
        #expect(planner.outlines == ["List", "List with Saved item"])
        #expect(outcome == .goalReached(steps: 0))
    }

    @Test("waits again on an unchanged screen, as for a slow save, until the stall limit ends it")
    func repeatedWait() async throws {
        let driver = FakeDriver(outlines: ["Saving"])
        let wait = StepPlan(action: .wait, confidence: 0.9, costUSD: 0)
        let outcome = try await AgentLoop(
            driver: driver, planner: FakePlanner([wait]), configuration: AgentConfiguration(goal: "g", maxSteps: 10),
        ).run().outcome
        #expect(outcome == .stalled(steps: 3))
    }

    @Test("taps a bar item that stayed in place across the last action without waiting for the confirming reading")
    func stableBarItem() async throws {
        let tab = UIEntry(
            aliases: ElementAliases(alias: 5), role: "RadioButton", label: "Map", states: [], value: nil, uniqueId: nil,
            region: ElementRegion(kind: "Group", label: "Tab Bar"), frame: ElementFrame(x: 90, y: 795, width: 85, height: 54),
        )
        let home = Fixtures.snapshot(outline: "Home", entries: [button(1, "Next", y: 300), tab])
        let detail = Fixtures.snapshot(outline: "Detail", entries: [Fixtures.entry(2, "Detail", role: "Heading"), tab])
        // A confirming reading that would have sent the plan back: were it awaited, the next plan would be on it.
        let moved = UIEntry(
            aliases: ElementAliases(alias: 5), role: "RadioButton", label: "Map", states: [], value: nil, uniqueId: nil,
            region: tab.region, frame: ElementFrame(x: 90, y: 760, width: 85, height: 54),
        )
        let sliding = Fixtures.snapshot(outline: "Detail sliding", entries: [moved])
        let mapScreen = Fixtures.snapshot(outline: "Map", entries: [Fixtures.entry(3, "Map", role: "Heading"), tab])
        let map = StepPlan(action: .tap(alias: 5, role: "RadioButton", label: "Map"), confidence: 0.95, costUSD: 0)
        let planner = RecordingFakePlanner([.tapNext(), map, .blocked()])
        let driver = ScriptedDriver(readings: [home, home, detail, sliding, mapScreen])
        _ = try await AgentLoop(driver: driver, planner: planner, configuration: AgentConfiguration(goal: "g")).run()
        #expect(driver.performedActions.prefix(2) == ["tap @1", "tap @5"])
        #expect(planner.outlines.prefix(3) == ["Home", "Detail", "Map"])
    }

    @Test("accepts DONE when the readings show the same elements and states in shifted places")
    func doneWhileAnimating() async throws {
        let planner = RecordingDonePlanner()
        let (loop, _) = loop([
            Fixtures.snapshot(outline: "Tabs moving", entries: [button(1, "Home", y: 800)]),
            Fixtures.snapshot(outline: "Tabs settled", entries: [button(1, "Home", y: 795)]),
        ], planner)
        let outcome = try await loop.run().outcome
        #expect(planner.outlines == ["Tabs moving"])
        #expect(outcome == .goalReached(steps: 0))
    }

    @Test("falls back to reading until two readings agree when the confirming readings keep disagreeing")
    func fallback() async throws {
        let planner = RecordingDonePlanner()
        let (loop, _) = loop((1 ... 9).map { Fixtures.snapshot(outline: "Frame \($0)") }, planner)
        _ = try await loop.run()
        #expect(planner.outlines == ["Frame 1", "Frame 2", "Frame 6"])
    }
}

/// Taps the element labelled `label` whenever it is on screen, else hands over; records each planned screen. The loop
/// refuses to repeat a tap that changed nothing, which ends the run.
private final class TapLabelPlanner: StepPlanning {
    private let label: String
    private let seen = Mutex<[String]>([])

    init(_ label: String) {
        self.label = label
    }

    var outlines: [String] {
        seen.withLock { $0 }
    }

    func plan(_ request: PlanRequest) async throws -> StepPlan {
        seen.withLock { $0.append(request.snapshot.outline) }
        guard let target = request.snapshot.entries?.first(where: { $0.label == label }) else { return .blocked() }
        return StepPlan(action: .tap(alias: target.aliases.alias, role: target.role, label: label), confidence: 0.9, costUSD: 0)
    }
}

/// Always judges the goal reached; records each planned screen.
private final class RecordingDonePlanner: StepPlanning {
    private let seen = Mutex<[String]>([])

    var outlines: [String] {
        seen.withLock { $0 }
    }

    func plan(_ request: PlanRequest) async throws -> StepPlan {
        seen.withLock { $0.append(request.snapshot.outline) }
        return .done()
    }
}

/// Judges the goal reached once an element's label contains `text`, and hands over before; records each planned screen.
private final class DoneWhenShownPlanner: StepPlanning {
    private let text: String
    private let seen = Mutex<[String]>([])

    init(_ text: String) {
        self.text = text
    }

    var outlines: [String] {
        seen.withLock { $0 }
    }

    func plan(_ request: PlanRequest) async throws -> StepPlan {
        seen.withLock { $0.append(request.snapshot.outline) }
        return request.snapshot.entries?.contains { $0.label.contains(text) } == true ? .done() : .blocked()
    }
}

@Suite("A tap whose element a revealing scroll lost")
struct AgentLoopRevealTests {
    @Test("is recorded as the scroll, so Jev does not believe the tap landed")
    func recordsScroll() async throws {
        let driver = LosingDriver()
        let result = try await AgentLoop(
            driver: driver, planner: FakePlanner([.tapNext(), .blocked()]), configuration: AgentConfiguration(goal: "g"),
        ).run()
        #expect(result.history.first?.action == SimUseDeviceAction.revealContentBelow.summary)
    }
}

/// Shows one screen and loses every tapped element to a revealing scroll.
private final class LosingDriver: DeviceDriving {
    func observe() async throws -> ScreenObservation {
        ScreenObservation(snapshot: Fixtures.snapshot(entries: [Fixtures.entry(1, "Next")]), disappearedApps: [])
    }

    func tap(alias _: Int, on _: UISnapshot) async throws -> [String] {
        throw SimUseError.targetNotRevealed(scroll: .revealContentBelow, disappearedApps: [])
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

/// Returns plans in order, repeating the last, and records each planned screen.
private final class RecordingFakePlanner: StepPlanning {
    private let plans: [StepPlan]
    private let seen = Mutex<[String]>([])

    init(_ plans: [StepPlan]) {
        self.plans = plans
    }

    var outlines: [String] {
        seen.withLock { $0 }
    }

    func plan(_ request: PlanRequest) async throws -> StepPlan {
        let count = seen.withLock { $0.append(request.snapshot.outline); return $0.count }
        return plans[min(count - 1, plans.count - 1)]
    }
}

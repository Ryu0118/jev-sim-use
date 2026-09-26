@testable import JevSimUseKit
import Synchronization
import Testing

@Suite("The same action repeated on a screen whose elements stay put is refused, even while a value there ticks")
struct RepeatGuardTests {
    /// A list whose one row shows a relative time that ticks after every action, and a filter button.
    static func list(minutes: Int, extra: [UIEntry] = []) -> UISnapshot {
        let row = UIEntry(
            aliases: ElementAliases(alias: 1), role: "Button", label: "Groceries", states: [],
            value: "Note, \(minutes) minutes ago", uniqueId: nil, region: nil, frame: nil,
        )
        return Fixtures.snapshot(outline: "list \(minutes)", entries: [row, Fixtures.entry(2, "Filter")] + extra)
    }

    static let openRow = AgentAction.tap(alias: 1, role: "Button", label: "Groceries")

    func observation(_ snapshot: UISnapshot) -> ScreenObservation {
        ScreenObservation(snapshot: snapshot, disappearedApps: [])
    }

    @Test("refuses a fourth identical tap after three that left the same elements, values aside")
    func refusesFourthRepeat() {
        var progress = AgentProgress()
        _ = progress.record(observation(Self.list(minutes: 0)), stallLimit: 5)
        for minute in 1 ... AgentProgress.repeatLimit {
            #expect(!progress.isFutileRepeat(Self.openRow))
            progress.recordAction(Self.openRow, disappeared: [])
            _ = progress.record(observation(Self.list(minutes: minute)), stallLimit: 5)
        }
        #expect(progress.ineffectiveActions.isEmpty)
        #expect(progress.isFutileRepeat(Self.openRow))
        #expect(!progress.isFutileRepeat(.tap(alias: 2, role: "Button", label: "Filter")))
        #expect(!progress.isFutileRepeat(.wait))
    }

    @Test("also refuses it when the screen alternates between two sets of elements")
    func refusesAlternatingRepeat() {
        let panel = [Fixtures.entry(3, "Sort by date")]
        var progress = AgentProgress()
        _ = progress.record(observation(Self.list(minutes: 0)), stallLimit: 9)
        for minute in 1 ... AgentProgress.repeatLimit {
            progress.recordAction(Self.openRow, disappeared: [])
            _ = progress.record(observation(Self.list(minutes: minute, extra: minute.isMultiple(of: 2) ? [] : panel)), stallLimit: 9)
        }
        #expect(progress.isFutileRepeat(Self.openRow))
    }

    @Test("allows the same action again when each one leads to a screen with other elements, like a Next button")
    func allowsProgressingRepeat() {
        var progress = AgentProgress()
        let next = AgentAction.tap(alias: 1, role: "Button", label: "Next")
        for page in 0 ... AgentProgress.repeatLimit {
            let snapshot = Fixtures.snapshot(outline: "page \(page)", entries: [Fixtures.entry(1, "Next"), Fixtures.entry(2, "Page \(page)", role: "StaticText")])
            _ = progress.record(observation(snapshot), stallLimit: 5)
            #expect(!progress.isFutileRepeat(next))
            progress.recordAction(next, disappeared: [])
        }
    }

    @Test("the loop hands over instead of tapping a row a fourth time on the same elements")
    func loopHandsOver() async throws {
        let driver = TickingListDriver()
        let plan = StepPlan(action: Self.openRow, confidence: 0.95, costUSD: 0)
        let outcome = try await AgentLoop(
            driver: driver, planner: FakePlanner([plan]), configuration: AgentConfiguration(goal: "g", maxSteps: 10),
        ).run().outcome
        #expect(outcome == .noActionFits(step: AgentProgress.repeatLimit + 1))
        #expect(driver.taps == AgentProgress.repeatLimit)
    }
}

/// Shows the list with one more minute on its relative time after every tap.
private final class TickingListDriver: DeviceDriving {
    private let count = Mutex(0)

    var taps: Int {
        count.withLock { $0 }
    }

    func observe() async throws -> ScreenObservation {
        ScreenObservation(snapshot: RepeatGuardTests.list(minutes: taps), disappearedApps: [])
    }

    func tap(alias _: Int, on _: UISnapshot) async throws -> [String] {
        count.withLock { $0 += 1 }
        return []
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

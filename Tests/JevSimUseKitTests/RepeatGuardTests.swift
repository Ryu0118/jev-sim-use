@testable import JevSimUseKit
import Synchronization
import Testing

/// A row tapped 26 times never opened while a relative time on it ticked, so every screen looked new. The time also
/// moves between two readings with no tap between, which is how the guard tells it from a tap's effect.
@Suite("The same action repeated on a screen whose elements stay put is refused, even while a value there ticks")
struct RepeatGuardTests {
    static let open = AgentAction.tap(alias: 1, role: "Button", label: "Open")

    /// A screen with the row to open, its relative time, and `extra` elements.
    static func screen(_ seconds: Int, _ extra: [String] = []) -> UISnapshot {
        let row = Fixtures.entry(1, "Open", value: "\(seconds) seconds ago")
        let others = extra.enumerated().map { Fixtures.entry($0.offset + 2, $0.element, role: "StaticText") }
        return Fixtures.snapshot(outline: "screen \(seconds) \(extra)", entries: [row] + others)
    }

    @Test("refuses the fourth identical action only when it keeps landing on the same elements", arguments: [
        ("the same elements, a value ticking", (0 ... 3).map { screen($0) }, true),
        // The first tap opens a new state, so the three repeats that led nowhere new are the second to the fourth.
        ("alternating between two sets of elements", (0 ... 4).map { screen($0, $0.isMultiple(of: 2) ? [] : ["Sort by date"]) }, true),
        ("a new page each time, like a Next button", (0 ... 3).map { screen($0, ["Page \($0)"]) }, false),
    ] as [(String, [UISnapshot], Bool)])
    func repeats(_: String, screens: [UISnapshot], futile: Bool) {
        var progress = AgentProgress()
        _ = progress.record(ScreenObservation(snapshot: screens[0], disappearedApps: []), stallLimit: 9)
        for screen in screens.dropFirst() {
            #expect(!progress.isFutileRepeat(Self.open), "refused before the limit")
            progress.recordAction(Self.open, disappeared: [])
            _ = progress.record(ScreenObservation(snapshot: screen, disappearedApps: []), stallLimit: 9)
            // The confirming reading, a moment later with no tap between, shows the time moved on.
            progress.noteReading(Self.screen(1000 + progress.steps, extraOf(screen)))
        }
        #expect(progress.isFutileRepeat(Self.open) == futile)
        #expect(!progress.isFutileRepeat(.tap(alias: 2, role: "Button", label: "Other")), "another action is never refused")
        #expect(!progress.isFutileRepeat(.wait), "waiting out a slow save is never refused")
    }

    @Test("the loop hands over instead of tapping a row a fourth time on the same elements")
    func loopHandsOver() async throws {
        let driver = TickingListDriver()
        let plan = StepPlan(action: Self.open, confidence: 0.95, costUSD: 0)
        let outcome = try await AgentLoop(
            driver: driver, planner: FakePlanner([plan]), configuration: AgentConfiguration(goal: "g", maxSteps: 10),
        ).run().outcome
        #expect(outcome == .noActionFits(step: AgentProgress.repeatLimit + 1))
        #expect(driver.taps == AgentProgress.repeatLimit)
    }

    /// The labels of `screen`'s elements after the row.
    private func extraOf(_ screen: UISnapshot) -> [String] {
        (screen.entries ?? []).dropFirst().map(\.label)
    }
}

/// Shows the list with one more second on its relative time on every reading, and counts the taps, which change
/// nothing.
private final class TickingListDriver: DeviceDriving {
    private let count = Mutex(0)
    private let reads = Mutex(0)

    var taps: Int {
        count.withLock { $0 }
    }

    func observe() async throws -> ScreenObservation {
        let seconds = reads.withLock { reads in
            reads += 1
            return reads
        }
        return ScreenObservation(snapshot: RepeatGuardTests.screen(seconds), disappearedApps: [])
    }

    func tap(alias _: Int, on _: UISnapshot) async throws -> [String] {
        count.withLock { $0 += 1 }
        return []
    }

    func perform(_: ElementGesture, alias _: Int, on _: UISnapshot) async throws -> [String] {
        []
    }

    func perform(_: SimUseDeviceAction, in _: ScreenSpace) async throws -> [String] {
        []
    }

    func paste(_: String, replacing _: Bool) async throws -> [String] {
        []
    }
}

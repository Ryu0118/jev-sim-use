@testable import JevSimUseKit
import Testing

/// Ways the loop's waits can go wrong once a screen-change watcher replaces back-to-back reads: reading too early,
/// trusting a change that was only a highlight, hanging on a screen that never stops moving, or changing what a run
/// without a watcher does.
@Suite("The loop waits on the screen-change watcher instead of polling reads, and polls as before without one")
struct ScreenWatchLoopTests {
    /// A screen with a heading named `name` and a Next button at alias 1, which `StepPlan.tapNext` taps.
    private static func screen(_ name: String) -> UISnapshot {
        Fixtures.snapshot(outline: name, entries: [Fixtures.entry(0, name, role: "Heading"), Fixtures.entry(1, "Next")])
    }

    private static func driver(_ names: [String], deadlines: CallDeadlines? = nil) -> ScriptedDriver {
        ScriptedDriver(readings: names.map(screen), deadlines: deadlines)
    }

    private static let configuration = AgentConfiguration(
        goal: "g", unchangedWait: .milliseconds(100), handOverWait: .milliseconds(100), minUnchangedReads: 3,
        minHandOverReads: 7, settleWait: .milliseconds(50),
    )

    @Test("reads once when an action changes nothing on screen, and still records it as having no visible effect")
    func noChangeReadsOnce() async throws {
        let driver = Self.driver(["A"])
        let watcher = ScriptedScreenWatcher(changes: [false])
        let result = try await AgentLoop(
            driver: driver, planner: FakePlanner([.tapNext(), .blocked()]), configuration: Self.configuration,
            screen: watcher,
        ).run()
        #expect(result.outcome == .tapHadNoEffect(step: 2, tap: #"Tap the Button labelled "Next""#))
        #expect(result.history.first?.screenChanged == false)
        // First reading, its confirmation, one after the tap, a confirmation, and one at the end of the hand-over wait.
        #expect(driver.readCount == 5)
        #expect(watcher.stillWaits == 0)
    }

    /// A tap's touch-down highlight changes the image and settles before the transition starts; one read then shows
    /// the old screen. Stopping there would record the tap as having done nothing.
    @Test("keeps waiting after a change that left the elements as they were, and sees the effect that follows it")
    func lateEffectAfterStillness() async throws {
        let driver = Self.driver(["A", "A", "A", "B"])
        let watcher = ScriptedScreenWatcher(changes: [true, true, false])
        let result = try await AgentLoop(
            driver: driver, planner: FakePlanner([.tapNext(), .blocked()]), configuration: Self.configuration,
            screen: watcher,
        ).run()
        #expect(result.history.first?.screenChanged == true)
        #expect(result.outcome == .noActionFits(step: 2))
        #expect(watcher.stillWaits == 2)
    }

    @Test("ends the wait at its deadline on a screen that never stops moving")
    func animationHitsDeadline() async throws {
        let driver = Self.driver(["A"])
        let watcher = ScriptedScreenWatcher(changes: [true], stills: [false])
        let started = ContinuousClock.now
        let outcome = try await AgentLoop(
            driver: driver, planner: FakePlanner([.tapNext(), .blocked()]), configuration: Self.configuration,
            screen: watcher,
        ).run().outcome
        #expect(outcome == .tapHadNoEffect(step: 2, tap: #"Tap the Button labelled "Next""#))
        #expect(ContinuousClock.now - started < .seconds(3))
    }

    /// A blinking caret changes the image every half second; the hand-over wait is there for a save that lands later.
    @Test("keeps waiting before a hand-over when a change leaves the layout as it was, without reading again for nothing")
    func handOverWaitsPastBlink() async throws {
        let driver = Self.driver(["A"])
        let planner = RecordingPlanner()
        let outcome = try await AgentLoop(
            driver: driver, planner: planner, configuration: Self.configuration,
            screen: ScriptedScreenWatcher(changes: [true, false]),
        ).run().outcome
        #expect(outcome == .noActionFits(step: 1))
        #expect(planner.outlines == ["A"])
        #expect(driver.readCount == 3)
    }

    @Test("plans again when the screen moves on during the hand-over wait")
    func handOverReplansOnChange() async throws {
        let driver = Self.driver(["A", "A", "B"])
        let planner = RecordingPlanner()
        _ = try await AgentLoop(
            driver: driver, planner: planner, configuration: Self.configuration,
            screen: ScriptedScreenWatcher(changes: [true, false]),
        ).run()
        #expect(planner.outlines == ["A", "B"])
    }

    /// On a loaded Mac a read took 2-4 s, and apps render as slowly: the wait lasts as long as its minimum reads would.
    @Test("stretches the wait for a change to the minimum reads at the device's read pace")
    func waitScalesWithReadPace() async throws {
        let deadlines = CallDeadlines(read: .seconds(8), action: .seconds(8), stretchedReadBaseline: .seconds(1))
        let watcher = ScriptedScreenWatcher(changes: [true, false])
        _ = try await AgentLoop(
            driver: Self.driver(["A", "A", "B"], deadlines: deadlines), planner: FakePlanner([.tapNext(), .done()]),
            configuration: Self.configuration, screen: watcher,
        ).run()
        #expect(try #require(watcher.changeSpans.first) > .milliseconds(2900))
    }

    @Test("reads back to back for at least the minimum reads when no watcher is available, as before")
    func withoutWatcherPolls() async throws {
        let driver = Self.driver(["A"])
        var configuration = Self.configuration
        configuration.unchangedWait = .zero
        configuration.handOverWait = .zero
        _ = try await AgentLoop(
            driver: driver, planner: FakePlanner([.tapNext(), .blocked()]), configuration: configuration,
        ).run()
        // First reading, its confirmation, three after the tap, a confirmation, and seven in the hand-over wait.
        #expect(driver.readCount == 13)
    }
}

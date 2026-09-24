@testable import JevSimUseKit
import Testing

struct AgentProgressTests {
    private let screenA = ScreenObservation(snapshot: Fixtures.snapshot(outline: "A"), disappearedApps: [])
    private let screenB = ScreenObservation(snapshot: Fixtures.snapshot(outline: "B"), disappearedApps: [])

    @Test("records whether each action changed the screen")
    func screenChanged() {
        var progress = AgentProgress()
        _ = progress.record(screenA, stallLimit: 3)
        progress.recordAction(.device(.goBack), disappeared: [])
        _ = progress.record(screenA, stallLimit: 3)
        progress.recordAction(.device(.revealContentBelow), disappeared: [])
        _ = progress.record(screenB, stallLimit: 3)
        #expect(progress.history.map(\.screenChanged) == [false, true])
        #expect(progress.history.map(\.step) == [1, 2])
    }

    @Test("never offers the same action twice on the same screen, even when screens alternate")
    func alternatingScreens() {
        var progress = AgentProgress()
        _ = progress.record(screenA, stallLimit: 5)
        progress.recordAction(.device(.revealContentBelow), disappeared: [])
        _ = progress.record(screenB, stallLimit: 5)
        progress.recordAction(.device(.revealContentBelow), disappeared: [])
        _ = progress.record(screenA, stallLimit: 5)
        #expect(progress.ineffectiveActions == ["scroll_to_reveal_below"])
    }

    @Test("stops when actions keep landing on screens already seen")
    func stallsOnRevisits() {
        var progress = AgentProgress()
        var outcome: AgentOutcome?
        _ = progress.record(screenA, stallLimit: 3)
        for screen in [screenB, screenA, screenB, screenA] where outcome == nil {
            progress.recordAction(.device(.revealContentBelow), disappeared: [])
            outcome = progress.record(screen, stallLimit: 3)
        }
        #expect(outcome == .stalled(steps: 4))
    }
}

@Suite("Resuming continues numbering but not the stop conditions of the earlier run")
struct AgentProgressResumeTests {
    private let screenA = ScreenObservation(snapshot: Fixtures.snapshot(outline: "A"), disappearedApps: [])

    @Test("numbers new steps after the continued history and counts only this run's steps")
    func continuesNumbering() {
        var progress = AgentProgress(history: [HistoryEntry(step: 1, action: "a"), HistoryEntry(step: 2, action: "b")])
        _ = progress.record(screenA, stallLimit: 3)
        progress.recordAction(.device(.goBack), disappeared: [])
        #expect(progress.history.map(\.step) == [1, 2, 3])
        #expect(progress.steps == 1)
    }

    @Test("does not treat the screen a resumed run starts on as tried or revisited")
    func freshLoopDetection() {
        var progress = AgentProgress(history: [HistoryEntry(step: 1, action: "a", screenChanged: false)])
        #expect(progress.record(screenA, stallLimit: 1) == nil)
        #expect(progress.ineffectiveActions.isEmpty)
    }
}

@Suite("A scroll that only moves frames at the end of a list is not a new screen")
struct ScreenIdentityTests {
    private func entry(_ label: String, y: Double, band: String) -> UIEntry {
        Fixtures.entry(1, label, frame: ElementFrame(x: 16, y: y, width: 370, height: 52), band: band)
    }

    @Test("ignores frames and bands, but not the elements shown")
    func bounce() {
        let before = Fixtures.snapshot(outline: "a", entries: [entry("Camera", y: 0, band: "Top"), entry("StandBy", y: 105, band: "Content")])
        let after = Fixtures.snapshot(outline: "b", entries: [entry("Camera", y: -35, band: "Top"), entry("StandBy", y: 70, band: "Top")])
        let other = Fixtures.snapshot(outline: "a", entries: [entry("Camera", y: 0, band: "Top"), entry("Search", y: 105, band: "Content")])
        #expect(before.identity == after.identity)
        #expect(before.identity != other.identity)
    }
}

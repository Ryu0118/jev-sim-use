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

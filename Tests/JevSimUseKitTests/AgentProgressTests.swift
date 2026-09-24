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

    @Test("excludes an action that did nothing until the screen changes")
    func ineffectiveActions() {
        var progress = AgentProgress()
        _ = progress.record(screenA, stallLimit: 3)
        progress.recordAction(.device(.goBack), disappeared: [])
        _ = progress.record(screenA, stallLimit: 3)
        #expect(progress.ineffectiveActions == ["go_back"])
        progress.recordAction(.device(.revealContentBelow), disappeared: [])
        _ = progress.record(screenB, stallLimit: 3)
        #expect(progress.ineffectiveActions.isEmpty)
    }
}

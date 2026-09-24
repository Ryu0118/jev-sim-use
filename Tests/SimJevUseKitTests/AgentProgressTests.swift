@testable import SimJevUseKit
import Testing

struct AgentProgressTests {
    @Test("marks an action whose screen did not change")
    func unchangedMarker() {
        var progress = AgentProgress()
        let screen = ScreenObservation(snapshot: Fixtures.snapshot(outline: "A"), disappearedApps: [])
        _ = progress.record(screen, stallLimit: 3)
        progress.recordAction(.device(.goBack), disappeared: [])
        _ = progress.record(screen, stallLimit: 3)
        #expect(progress.history == ["Go back to the previous screen (screen unchanged)"])
    }
}

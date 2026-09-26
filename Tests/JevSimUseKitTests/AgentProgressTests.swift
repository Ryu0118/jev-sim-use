@testable import JevSimUseKit
import Testing

struct AgentProgressTests {
    private let screenA = ScreenObservation(snapshot: Fixtures.snapshot(outline: "A"), disappearedApps: [])
    private let screenB = ScreenObservation(snapshot: Fixtures.snapshot(outline: "B"), disappearedApps: [])

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

@Suite("A resumed run starts loop detection fresh")
struct AgentProgressResumeTests {
    private let screenA = ScreenObservation(snapshot: Fixtures.snapshot(outline: "A"), disappearedApps: [])

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

@Suite("A section entered and left again is not offered again from the same screen")
struct ExploredBranchTests {
    private func screen(_ title: String, _ items: [String]) -> ScreenObservation {
        let entries = [Fixtures.entry(0, title, role: "Heading")] + items.enumerated().map { Fixtures.entry($0.offset + 1, $0.element) }
        return ScreenObservation(snapshot: Fixtures.snapshot(outline: title, entries: entries), disappearedApps: [])
    }

    @Test("records the tapped element as explored once the title changes, and keys it by the parent title")
    func explored() {
        var progress = AgentProgress()
        _ = progress.record(screen("設定", ["一般", "カメラ"]), stallLimit: 5)
        progress.recordAction(.tap(alias: 1, role: "Button", label: "一般"), disappeared: [])
        _ = progress.record(screen("一般", ["情報"]), stallLimit: 5)
        #expect(progress.exploredElements.isEmpty)
        progress.recordAction(.device(.goBack), disappeared: [])
        _ = progress.record(screen("設定", ["カメラ", "一般"]), stallLimit: 5)
        #expect(progress.exploredElements == ["一般"])
    }

    @Test("a tap that keeps the title, like a switch, is not an explored branch")
    func sameTitle() {
        var progress = AgentProgress()
        _ = progress.record(screen("キーボード", ["自動修正"]), stallLimit: 5)
        progress.recordAction(.tap(alias: 1, role: "CheckBox", label: "自動修正"), disappeared: [])
        _ = progress.record(screen("キーボード", ["自動修正", "x"]), stallLimit: 5)
        #expect(progress.exploredElements.isEmpty)
    }
}

@testable import JevSimUseKit
import Testing

struct TwoFingerSelectionTests {
    private func row(_ alias: Int, y: Double) -> UIEntry {
        Fixtures.entry(alias, "Row \(alias)", role: "StaticText", frame: ElementFrame(x: 0, y: y, width: 402, height: 43))
    }

    @Test("drags two fingers from the first row a list shows to its last, whatever else is on screen")
    func spansTheList() throws {
        let snapshot = Fixtures.snapshot(entries: [
            row(1, y: 168), row(2, y: 211), row(3, y: 254),
            Fixtures.entry(4, "New", frame: ElementFrame(x: 331, y: 803, width: 38, height: 38)),
        ])
        let rows = try #require(snapshot.rowRun)
        #expect(SimUseDeviceAction.selectRows(from: rows.first, to: rows.last).arguments(in: ScreenSpace(platform: "ios")) == [
            "multi-touch", "--x1", "181.0", "--y1", "189.5", "--x2", "221.0", "--y2", "189.5",
            "--x1-end", "181.0", "--y1-end", "275.5", "--x2-end", "221.0", "--y2-end", "275.5", "--duration", "0.8",
        ])
    }

    @Test("ends on the last row within reach, not on one under the tab bar")
    func skipsCoveredRows() throws {
        let tabBar = Fixtures.entry(9, "Tabs", role: "Group", frame: ElementFrame(x: 0, y: 795, width: 402, height: 54))
        let snapshot = Fixtures.snapshot(entries: [row(1, y: 168), row(2, y: 211), row(3, y: 820), tabBar])
        let rows = try #require(snapshot.rowRun)
        #expect(rows.last.y == 211)
    }
}

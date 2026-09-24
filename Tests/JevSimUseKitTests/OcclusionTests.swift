@testable import JevSimUseKit
import Testing

struct OcclusionTests {
    private func entry(_ alias: Int, _ frame: ElementFrame, role: String = "Button", depth: Int = 2) -> UIEntry {
        var entry = Fixtures.entry(alias, "e\(alias)", role: role, frame: frame)
        entry.depth = depth
        return entry
    }

    @Test("taps the part of a row the floating search bar leaves clear")
    func underSearchBar() throws {
        let row = entry(15, ElementFrame(x: 16, y: 789, width: 370, height: 52))
        let search = entry(16, ElementFrame(x: 33, y: 803, width: 336, height: 38), role: "TextField", depth: 1)
        let screen = entry(9, ElementFrame(x: 0, y: 0, width: 402, height: 874), role: "Group")
        let point = try #require(Fixtures.snapshot(entries: [screen, row, search]).uncoveredPoint(of: row))
        #expect(point.y > 789 && point.y < 803)
        #expect(point.x == 201)
    }

    @Test("leaves an uncovered element to sim-use's own centre tap, and ignores its children")
    func clear() {
        let row = entry(1, ElementFrame(x: 0, y: 100, width: 400, height: 50))
        let label = entry(2, ElementFrame(x: 150, y: 110, width: 100, height: 20), role: "StaticText", depth: 3)
        #expect(Fixtures.snapshot(entries: [row, label]).uncoveredPoint(of: row) == nil)
    }
}

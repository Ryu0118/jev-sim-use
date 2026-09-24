import Foundation
@testable import JevSimUseKit
import Testing

struct OcclusionTests {
    private func entry(_ alias: Int, _ label: String, _ frame: ElementFrame, role: String = "Button", depth: Int = 2) -> UIEntry {
        var entry = Fixtures.entry(alias, label, role: role, frame: frame)
        entry.depth = depth
        return entry
    }

    private var row: UIEntry {
        entry(15, "デベロッパ", ElementFrame(x: 16, y: 789, width: 370, height: 52))
    }

    private var search: UIEntry {
        entry(16, "検索", ElementFrame(x: 33, y: 803, width: 336, height: 38), role: "TextField", depth: 1)
    }

    @Test("a row under the floating search bar is marked covered and is not a tap target")
    func underSearchBar() throws {
        let screen = entry(9, "", ElementFrame(x: 0, y: 0, width: 402, height: 874), role: "Group", depth: 0)
        let snapshot = Fixtures.snapshot(entries: [screen, row, search])
        #expect(snapshot.cover(of: row)?.label == "検索")
        #expect(!ActionCatalog.menu(for: snapshot, texts: []).elements.map(\.alias).contains(15))
        let json = try String(decoding: JSONEncoder().encode(PlanningState.Screen(snapshot)), as: UTF8.self)
        #expect(json.contains(#""covered_by":"検索""#))
    }

    @Test("a row's own children do not cover it")
    func children() {
        let label = entry(2, "Wi-Fi", ElementFrame(x: 150, y: 800, width: 100, height: 20), role: "StaticText", depth: 3)
        #expect(Fixtures.snapshot(entries: [row, label]).cover(of: row) == nil)
    }
}

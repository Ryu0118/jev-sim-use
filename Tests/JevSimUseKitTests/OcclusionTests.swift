import Foundation
@testable import JevSimUseKit
import Testing

/// sim-use taps an element's centre, so a target another element floats over must be scrolled into reach first. The
/// successful reveal (scroll, read again, tap at the new alias) runs end to end in scripts/e2e.sh; these are the cases
/// a cover or reveal decision can get wrong, each from a real run.
@Suite("Which element swallows a tap on a target, and which scroll brings the target into reach")
struct OcclusionTests {
    private static let screen = ElementFrame(x: 0, y: 0, width: 402, height: 874)
    private static let row = entry(15, "Target row", ElementFrame(x: 16, y: 789, width: 370, height: 52))
    private static let searchBar = entry(16, "Search", ElementFrame(x: 33, y: 803, width: 336, height: 38), role: "TextField", depth: 1)
    private static let tab = UIEntry(
        aliases: ElementAliases(alias: 51), role: "RadioButton", label: "History", states: [], value: nil, uniqueId: nil,
        region: ElementRegion(kind: "Group", label: "Tab Bar"), frame: ElementFrame(x: 25, y: 795, width: 98, height: 54),
    )
    private static let floatingButton = entry(24, "Create", ElementFrame(x: 326, y: 704, width: 56, height: 56), depth: 1)

    @Test("finds the element that would swallow a tap, and only that", arguments: [
        ("a floating search bar over the row's centre covers it", row, [entry(9, "", screen, role: "Group", depth: 0), searchBar], "Search"),
        ("the bar also covers a row whose centre sits just above its text field",
         entry(15, "Target row", ElementFrame(x: 16, y: 775, width: 370, height: 52)), [searchBar], "Search"),
        ("a neighbouring row that only touches the edge does not", row,
         [entry(14, "Row above", ElementFrame(x: 16, y: 737, width: 370, height: 52), depth: 1)], nil),
        ("a deeper list row does not cover a floating button whose centre it holds", floatingButton,
         [entry(22, "List row", ElementFrame(x: 0, y: 726, width: 402, height: 69))], nil),
        ("a row's own children do not", row,
         [entry(2, "Row label", ElementFrame(x: 150, y: 800, width: 100, height: 20), role: "StaticText", depth: 3)], nil),
        ("content scrolled under the tab bar does not cover a tab, which the bar draws on top", tab,
         [entry(13, "10:35 - 10:37", ElementFrame(x: 50, y: 806, width: 105, height: 20), role: "StaticText")], nil),
    ] as [(String, UIEntry, [UIEntry], String?)])
    func cover(_: String, target: UIEntry, others: [UIEntry], expected: String?) {
        #expect(Fixtures.snapshot(entries: others + [target]).cover(of: target)?.label == expected)
    }

    @Test("scrolls toward a target out of reach, and leaves one in reach alone", arguments: [
        ("a switch whose centre lies below the screen reveals content below",
         entry(29, "Switch", ElementFrame(x: 32, y: 870, width: 338, height: 28), role: "CheckBox"), [], SimUseDeviceAction?.some(.revealContentBelow)),
        ("a row under a bottom overlay reveals content below even when its centre is below the overlay's",
         entry(15, "Target row", ElementFrame(x: 16, y: 800, width: 370, height: 52)), [searchBar], .revealContentBelow),
        ("a row above the top of the screen reveals content above",
         entry(15, "Target row", ElementFrame(x: 16, y: -60, width: 370, height: 52)), [], .revealContentAbove),
        ("a row in reach needs no scroll", entry(15, "Target row", ElementFrame(x: 16, y: 300, width: 370, height: 52)), [], nil),
    ] as [(String, UIEntry, [UIEntry], SimUseDeviceAction?)])
    func revealingScroll(_: String, target: UIEntry, others: [UIEntry], expected: SimUseDeviceAction?) {
        var snapshot = Fixtures.snapshot(entries: others + [target])
        snapshot.screen = Self.screen
        #expect(snapshot.revealingScroll(for: target) == expected)
    }

    @Test("reports the scroll alone when the target is gone from the screen the scroll revealed")
    func revealedTargetGone() async throws {
        let runner = FakeCommandRunner([
            "gesture": .json(#"{"ok":true,"data":{}}"#),
            "ui": .json(#"""
            {"ok":true,"data":{"platform":"ios","outline":"moved","screen":{"x":0,"y":0,"width":402,"height":874},
            "entries":[{"aliases":{"at":7},"role":"Button","label":"Other","states":[],"depth":2,
            "frame":{"x":16,"y":500,"width":370,"height":44}}]}}
            """#),
        ])
        let client = SimUseClient(
            device: SimUseDevice(deviceId: "D", name: "iPhone", platform: "ios", kind: "simulator", state: "Booted"),
            invoker: SimUseInvoker(executable: URL(filePath: "/sim-use"), runner: runner),
        )
        await #expect(throws: SimUseError.targetNotRevealed(scroll: .revealContentBelow, disappearedApps: [])) {
            try await client.tap(alias: 15, on: Fixtures.snapshot(entries: [Self.row, Self.searchBar]))
        }
        #expect(runner.recordedCalls.map(\.first) == ["gesture", "ui", "ui"])
    }

    private static func entry(
        _ alias: Int, _ label: String, _ frame: ElementFrame, role: String = "Button", depth: Int = 2,
    ) -> UIEntry {
        var entry = Fixtures.entry(alias, label, role: role, frame: frame)
        entry.depth = depth
        return entry
    }
}

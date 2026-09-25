import Foundation
@testable import JevSimUseKit
import Testing

struct OcclusionTests {
    @Test("content scrolled under the tab bar does not cover a tab, which the bar draws on top of it")
    func tabOverContent() {
        let tab = UIEntry(
            aliases: ElementAliases(alias: 51), role: "RadioButton", label: "History", states: [], value: nil, uniqueId: nil,
            region: ElementRegion(kind: "Group", label: "Tab Bar"), frame: ElementFrame(x: 25, y: 795, width: 98, height: 54),
        )
        let time = entry(13, "10:35 - 10:37", ElementFrame(x: 50, y: 806, width: 105, height: 20), role: "StaticText")
        #expect(Fixtures.snapshot(entries: [time, tab]).cover(of: tab) == nil)
    }

    private var row: UIEntry {
        entry(15, "デベロッパ", ElementFrame(x: 16, y: 789, width: 370, height: 52))
    }

    private var search: UIEntry {
        entry(16, "検索", ElementFrame(x: 33, y: 803, width: 336, height: 38), role: "TextField", depth: 1)
    }

    @Test("a row under the floating search bar is marked covered_by it in the state")
    func underSearchBar() throws {
        let screen = entry(9, "", ElementFrame(x: 0, y: 0, width: 402, height: 874), role: "Group", depth: 0)
        let snapshot = Fixtures.snapshot(entries: [screen, row, search])
        #expect(snapshot.cover(of: row)?.label == "検索")
        let json = try String(decoding: JSONEncoder().encode(PlanningState.Screen(snapshot)), as: UTF8.self)
        #expect(json.contains(#""covered_by":"検索""#))
    }

    @Test("the search bar covers a row whose centre sits just above the bar's text field")
    func centreAboveSearchBar() {
        let developer = entry(15, "デベロッパ", ElementFrame(x: 16, y: 775, width: 370, height: 52))
        #expect(Fixtures.snapshot(entries: [developer, search]).cover(of: developer)?.label == "検索")
    }

    @Test("a neighbouring row that only touches the edge does not cover it")
    func touchingNeighbour() {
        let above = entry(14, "アプリ", ElementFrame(x: 16, y: 737, width: 370, height: 52), depth: 1)
        #expect(Fixtures.snapshot(entries: [above, row]).cover(of: row) == nil)
    }

    @Test("a deeper list row does not cover a floating button whose centre it holds")
    func floatingButton() {
        let fab = entry(24, "Create", ElementFrame(x: 326, y: 704, width: 56, height: 56), depth: 1)
        let row = entry(22, "Groceries", ElementFrame(x: 0, y: 726, width: 402, height: 69), depth: 2)
        #expect(Fixtures.snapshot(entries: [row, fab]).cover(of: fab) == nil)
    }

    @Test("a row's own children do not cover it")
    func children() {
        let label = entry(2, "Wi-Fi", ElementFrame(x: 150, y: 800, width: 100, height: 20), role: "StaticText", depth: 3)
        #expect(Fixtures.snapshot(entries: [row, label]).cover(of: row) == nil)
    }

    @Test("a covered row is scrolled into view, read again, and tapped at its new alias")
    func revealsThenTaps() async throws {
        let runner = FakeCommandRunner([
            "gesture": .json(#"{"ok":true,"data":{}}"#), "tap": .json(#"{"ok":true,"data":{}}"#),
            "ui": reading(role: "Button", label: "Developer", y: 500),
        ])
        let developer = entry(15, "Developer", ElementFrame(x: 16, y: 789, width: 370, height: 52))
        _ = try await client(runner).tap(alias: 15, on: Fixtures.snapshot(entries: [developer, search]))
        #expect(runner.recordedCalls.map { Array($0.prefix(2)) } == [
            ["gesture", "scroll-up"], ["ui", "--device"], ["ui", "--device"], ["tap", "@7"],
        ])
    }

    @Test("a switch whose centre lies below the screen is scrolled up, then tapped on its trailing edge")
    func offscreenSwitch() async throws {
        let runner = FakeCommandRunner([
            "gesture": .json(#"{"ok":true,"data":{}}"#), "tap": .json(#"{"ok":true,"data":{}}"#),
            "ui": reading(role: "CheckBox", label: "Reminders", y: 600),
        ])
        let toggle = entry(29, "Reminders", ElementFrame(x: 32, y: 870, width: 338, height: 28), role: "CheckBox")
        var snapshot = Fixtures.snapshot(entries: [toggle])
        snapshot.screen = ElementFrame(x: 0, y: 0, width: 402, height: 874)
        #expect(snapshot.revealingScroll(for: toggle) == .revealContentBelow)
        _ = try await client(runner).tap(alias: 29, on: snapshot)
        #expect(runner.recordedCalls.map { Array($0.prefix(5)) } == [
            ["gesture", "scroll-up", "--duration", "1.5", "--device"], ["ui", "--device", "D", "--json"],
            ["ui", "--device", "D", "--json"], ["tap", "-x", "360.0", "-y", "622.0"],
        ])
    }

    @Test("reports the scroll alone when the element is gone from the screen it revealed")
    func revealedElementGone() async throws {
        let runner = FakeCommandRunner([
            "gesture": .json(#"{"ok":true,"data":{}}"#), "ui": reading(role: "Button", label: "Other", y: 500),
        ])
        let developer = entry(15, "Developer", ElementFrame(x: 16, y: 789, width: 370, height: 52))
        await #expect(throws: SimUseError.targetNotRevealed(scroll: .revealContentBelow, disappearedApps: [])) {
            try await client(runner).tap(alias: 15, on: Fixtures.snapshot(entries: [developer, search]))
        }
        #expect(runner.recordedCalls.map(\.first) == ["gesture", "ui", "ui"])
    }

    @Test("reveals content below for a bottom overlay even when the row's centre sits below the overlay's")
    func directionFromScreenHalf() async {
        let runner = FakeCommandRunner([
            "gesture": .json(#"{"ok":true,"data":{}}"#), "ui": reading(role: "Button", label: "Other", y: 500),
        ])
        let low = UIEntry(
            aliases: ElementAliases(alias: 15), role: "Button", label: "デベロッパ", states: [], value: nil,
            uniqueId: "com.apple.settings.developer", region: nil,
            frame: ElementFrame(x: 16, y: 800, width: 370, height: 52), depth: 2,
        )
        let screen = entry(9, "", ElementFrame(x: 0, y: 0, width: 402, height: 874), role: "Group", depth: 0)
        _ = try? await client(runner).tap(alias: 15, on: Fixtures.snapshot(entries: [screen, low, search]))
        #expect(runner.recordedCalls.first?.prefix(2) == ["gesture", "scroll-up"])
    }

    private func entry(_ alias: Int, _ label: String, _ frame: ElementFrame, role: String = "Button", depth: Int = 2) -> UIEntry {
        var entry = Fixtures.entry(alias, label, role: role, frame: frame)
        entry.depth = depth
        return entry
    }

    private func client(_ runner: FakeCommandRunner) -> SimUseClient {
        SimUseClient(
            device: SimUseDevice(deviceId: "D", name: "iPhone", platform: "ios", kind: "simulator", state: "Booted"),
            invoker: SimUseInvoker(executable: URL(filePath: "/sim-use"), runner: runner),
        )
    }

    /// A `ui` envelope whose only element is `role`/`label` with alias 7 at `y`, on a 402x874 screen.
    private func reading(role: String, label: String, y: Int) -> CommandOutput {
        .json(#"""
        {"ok":true,"data":{"platform":"ios","outline":"moved","screen":{"x":0,"y":0,"width":402,"height":874},
        "entries":[{"aliases":{"at":7},"role":"\#(role)","label":"\#(label)","states":[],"depth":2,
        "frame":{"x":16,"y":\#(y),"width":370,"height":44}}]}}
        """#)
    }
}

import Foundation
@testable import JevSimUseKit
import Testing

struct OcclusionTests {
    @Test(
        "content scrolled under the tab bar does not cover a tab, which the bar draws on top of it, in any band",
        arguments: [ElementRegion(kind: "Group", label: "Tab Bar"), ElementRegion(kind: "Bottom", label: nil)],
    )
    func tabOverContent(region: ElementRegion) {
        var tab = UIEntry(
            aliases: ElementAliases(alias: 51), role: "RadioButton", label: "History", states: [], value: nil, uniqueId: nil,
            region: region, frame: ElementFrame(x: 25, y: 795, width: 98, height: 54), depth: 2,
        )
        tab.traits = ["Button", "TabButton"]
        let time = entry(13, "10:35 - 10:37", ElementFrame(x: 50, y: 806, width: 105, height: 20), role: "StaticText")
        // A grid image sits shallower than the tabs and would float over one.
        let image = entry(14, "Photo", ElementFrame(x: 0, y: 760, width: 133, height: 133), role: "Image", band: "Bottom", depth: 1)
        #expect(Fixtures.snapshot(entries: [time, image, tab]).cover(of: tab) == nil)
    }

    /// A day view: the week strip's container and the date header sit shallower than the timeline, whose rows sim-use
    /// puts in a labelled group. Frames from an iOS 26 reading.
    private var dayView: (container: UIEntry, header: UIEntry, strip: UIEntry, event: UIEntry) {
        let timeline = ElementRegion(kind: "Group", label: "Day")
        let container = entry(8, "", ElementFrame(x: 0, y: 62, width: 402, height: 121), role: "Group", band: "Content", depth: 1)
        let header = entry(16, "Date", ElementFrame(x: 119, y: 192, width: 164, height: 18), role: "Heading", band: "Content", depth: 1)
        let strip = entry(13, "Next day", ElementFrame(x: 287, y: 133, width: 57, height: 43), region: timeline)
        let event = entry(15, "Event", ElementFrame(x: 68, y: 168, width: 332, height: 50), region: timeline)
        return (container, header, strip, event)
    }

    @Test("an event row scrolled under the week strip is covered by the strip's container, and is revealed by scrolling up")
    func eventUnderWeekStrip() {
        let view = dayView
        let screen = entry(1, "", ElementFrame(x: 0, y: 0, width: 402, height: 874), role: "Group", depth: 0)
        let snapshot = Fixtures.snapshot(entries: [screen, view.container, view.strip, view.event, view.header])
        #expect(snapshot.cover(of: view.event) != nil)
        #expect(snapshot.revealingScroll(for: view.event) == .revealContentAbove)
    }

    @Test("a day button in a labelled group is not covered by the container around it or by an hour row under the strip")
    func dayButtonStaysTappable() {
        let view = dayView
        // The hour row scrolled under the strip, in the content band as in the reading.
        let row = entry(9, "Hour", ElementFrame(x: 62, y: 118, width: 340, height: 50), role: "StaticText", band: "Content")
        #expect(Fixtures.snapshot(entries: [view.container, row, view.strip, view.header]).cover(of: view.strip) == nil)
    }

    @Test("a segment of a segmented control, which lacks the tab trait, is still covered by what floats over it")
    func segmentIsNotTab() {
        var segment = entry(8, "Events", ElementFrame(x: 72, y: 780, width: 129, height: 48), role: "RadioButton", band: "Bottom")
        segment.traits = ["Button", "Selected"]
        let overlay = entry(9, "Menu", ElementFrame(x: 40, y: 760, width: 200, height: 60), band: "Bottom", depth: 1)
        #expect(Fixtures.snapshot(entries: [segment, overlay]).cover(of: segment)?.label == "Menu")
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

    private var inlineTitle: UIEntry {
        entry(3, "Settings", ElementFrame(x: 185, y: 74, width: 32, height: 21), role: "Heading", band: "Top", depth: 1)
    }

    @Test("a row scrolled up above the inline title lies under the top bar and is revealed by scrolling content above")
    func aboveInlineTitle() {
        let row = entry(2, "General", ElementFrame(x: 16, y: 9, width: 370, height: 52), band: "Top")
        var snapshot = Fixtures.snapshot(entries: [row, inlineTitle])
        snapshot.screen = ElementFrame(x: 0, y: 0, width: 402, height: 874)
        #expect(snapshot.cover(of: row)?.label == "Settings")
        #expect(snapshot.revealingScroll(for: row) == .revealContentAbove)
    }

    @Test("a row whose centre sits below the top bar's items is not covered by them")
    func belowInlineTitle() {
        let row = entry(5, "General", ElementFrame(x: 16, y: 113, width: 370, height: 52), band: "Content")
        #expect(Fixtures.snapshot(entries: [row, inlineTitle]).cover(of: row) == nil)
    }

    @Test("top bar items at one depth do not cover each other")
    func barItemsBesideEachOther() {
        let back = entry(7, "Back", ElementFrame(x: 16, y: 62, width: 44, height: 44), band: "Top", depth: 1)
        let edit = entry(8, "Edit", ElementFrame(x: 326, y: 66, width: 56, height: 36), band: "Top", depth: 1)
        let snapshot = Fixtures.snapshot(entries: [back, inlineTitle, edit])
        #expect(snapshot.cover(of: back) == nil)
        #expect(snapshot.cover(of: edit) == nil)
    }

    @Test("a sheet's bar items inside its shallower bar group are not covered by the grabber above them")
    func sheetBarItems() {
        let grabber = entry(2, "Grabber", ElementFrame(x: 151, y: 58, width: 100, height: 24), band: "Top", depth: 1)
        let close = entry(3, "Close", ElementFrame(x: 20, y: 82, width: 36, height: 36), band: "Top")
        let barGroup = entry(6, "", ElementFrame(x: 0, y: 78, width: 402, height: 54), role: "Group", band: "Top", depth: 1)
        #expect(Fixtures.snapshot(entries: [grabber, close, barGroup]).cover(of: close) == nil)
    }

    @Test("on Android a row above a shallower top item is not covered, since its frame is clipped to what shows")
    func androidTopBand() {
        let row = entry(2, "General", ElementFrame(x: 16, y: 9, width: 370, height: 52), band: "Top")
        let snapshot = UISnapshot(platform: "android", outline: "o", appLabel: "App", entries: [row, inlineTitle], crashDialog: nil)
        #expect(snapshot.cover(of: row) == nil)
    }

    private func entry(
        _ alias: Int, _ label: String, _ frame: ElementFrame, role: String = "Button", band: String? = nil, depth: Int = 2,
        region: ElementRegion? = nil,
    ) -> UIEntry {
        var entry = Fixtures.entry(alias, label, role: role, frame: frame, band: band, region: region)
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

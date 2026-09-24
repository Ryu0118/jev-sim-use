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

    @Test("a row under the floating search bar is marked covered_by it in the state")
    func underSearchBar() throws {
        let screen = entry(9, "", ElementFrame(x: 0, y: 0, width: 402, height: 874), role: "Group", depth: 0)
        let snapshot = Fixtures.snapshot(entries: [screen, row, search])
        #expect(snapshot.cover(of: row)?.label == "検索")
        let json = try String(decoding: JSONEncoder().encode(PlanningState.Screen(snapshot)), as: UTF8.self)
        #expect(json.contains(#""covered_by":"検索""#))
    }

    @Test("a row's own children do not cover it")
    func children() {
        let label = entry(2, "Wi-Fi", ElementFrame(x: 150, y: 800, width: 100, height: 20), role: "StaticText", depth: 3)
        #expect(Fixtures.snapshot(entries: [row, label]).cover(of: row) == nil)
    }

    @Test("a covered row is scrolled into view, then tapped by a fresh selector")
    func revealsThenTaps() async throws {
        let runner = FakeCommandRunner(["gesture": .json(#"{"ok":true,"data":{}}"#), "tap": .json(#"{"ok":true,"data":{}}"#)])
        var developer = row
        developer = UIEntry(
            aliases: developer.aliases, role: developer.role, label: developer.label, states: [], value: nil,
            uniqueId: "com.apple.settings.developer", region: nil, frame: developer.frame, depth: 2,
        )
        let client = SimUseClient(
            device: SimUseDevice(deviceId: "D", name: "iPhone", platform: "ios", kind: "simulator", state: "Booted"),
            invoker: SimUseInvoker(executable: URL(filePath: "/sim-use"), runner: runner),
        )
        _ = try await client.tap(alias: 15, on: Fixtures.snapshot(entries: [developer, search]))
        #expect(runner.recordedCalls.map { Array($0.prefix(3)) } == [
            ["gesture", "scroll-up", "--device"], ["tap", "--id", "com.apple.settings.developer"],
        ])
    }

    @Test("reveals content below for a bottom overlay even when the row's centre sits below the overlay's")
    func directionFromScreenHalf() async throws {
        let runner = FakeCommandRunner(["gesture": .json(#"{"ok":true,"data":{}}"#), "tap": .json(#"{"ok":true,"data":{}}"#)])
        let low = UIEntry(
            aliases: ElementAliases(alias: 15), role: "Button", label: "デベロッパ", states: [], value: nil,
            uniqueId: "com.apple.settings.developer", region: nil,
            frame: ElementFrame(x: 16, y: 800, width: 370, height: 52), depth: 2,
        )
        let screen = entry(9, "", ElementFrame(x: 0, y: 0, width: 402, height: 874), role: "Group", depth: 0)
        let client = SimUseClient(
            device: SimUseDevice(deviceId: "D", name: "iPhone", platform: "ios", kind: "simulator", state: "Booted"),
            invoker: SimUseInvoker(executable: URL(filePath: "/sim-use"), runner: runner),
        )
        _ = try await client.tap(alias: 15, on: Fixtures.snapshot(entries: [screen, low, search]))
        #expect(runner.recordedCalls.first?.prefix(2) == ["gesture", "scroll-up"])
    }
}

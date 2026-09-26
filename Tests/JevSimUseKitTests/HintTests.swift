import Foundation
@testable import JevSimUseKit
import Synchronization
import Testing

/// iOS sim-use leaves `entries[].hint` empty and keeps the hint as the raw tree's `help`. Sending hints only on the
/// retry before a hand-over runs end to end in scripts/e2e.sh; these are the ways matching a raw node to an entry can
/// go wrong.
@Suite("An iOS accessibility hint reaches the element it belongs to, unless many elements share it")
struct HintTests {
    private static func entry(_ label: String, y: Int) -> String {
        #"{"aliases":{"at":1},"role":"Button","label":"\#(label)","states":[],"frame":{"x":16,"y":\#(y),"width":56,"height":56}}"#
    }

    private static func node(_ label: String?, y: Double, help: String) -> String {
        let label = label.map { #""\#($0)""# } ?? "null"
        return #"{"AXLabel":\#(label),"help":"\#(help)","frame":{"x":16.2,"y":\#(y),"width":56,"height":56},"children":[]}"#
    }

    @Test("copies a raw node's help only to the entry at the same place with the same or no label", arguments: [
        ("same place and label, rounded", [entry("Assistant", y: 700)], [node("Assistant", y: 700.3, help: "Rewrites it")], ["Rewrites it"]),
        ("same place, node without a label", [entry("Assistant", y: 700)], [node(nil, y: 700, help: "Rewrites it")], ["Rewrites it"]),
        ("another place", [entry("Edit", y: 66)], [node("Edit", y: 700, help: "Rewrites it")], [nil]),
        ("same place, another label", [entry("Edit", y: 700)], [node("Assistant", y: 700, help: "Rewrites it")], [nil]),
        ("shared by three elements, like the status bar's gesture help",
         [entry("A", y: 10), entry("B", y: 100), entry("C", y: 200)],
         [node("A", y: 10, help: "Swipe down"), node("B", y: 100, help: "Swipe down"), node("C", y: 200, help: "Swipe down")],
         [nil, nil, nil]),
    ] as [(String, [String], [String], [String?])])
    func hints(_: String, entries: [String], nodes: [String], expected: [String?]) throws {
        let json = #"{"platform":"ios","outline":"o","entries":[\#(entries.joined(separator: ","))],"raw":[{"AXLabel":null,"frame":{"x":0,"y":0,"width":402,"height":874},"children":[\#(nodes.joined(separator: ","))]}]}"#
        let snapshot = try JSONDecoder().decode(UISnapshot.self, from: Data(json.utf8))
        #expect(snapshot.entries?.map(\.hint) == expected)
    }
}

/// Serves one screen whose button carries a hint, and records the taps.
private final class HintedScreenDriver: DeviceDriving {
    private let taps = Mutex(0)
    var tapCount: Int {
        taps.withLock { $0 }
    }

    func observe() async throws -> ScreenObservation {
        var entry = Fixtures.entry(1, "Assistant")
        entry.hint = "Rewrites this memo from your instruction"
        let snapshot = Fixtures.snapshot(outline: taps.withLock { "screen \($0)" }, entries: [entry])
        return ScreenObservation(snapshot: snapshot, disappearedApps: [])
    }

    func tap(alias _: Int, on _: UISnapshot) async throws -> [String] {
        taps.withLock { $0 += 1 }
        return []
    }

    func perform(_: ElementGesture, alias _: Int, on _: UISnapshot) async throws -> [String] {
        []
    }

    func perform(_: SimUseDeviceAction, in _: ScreenSpace) async throws -> [String] {
        []
    }

    func paste(_: String, replacing _: Bool) async throws -> [String] {
        []
    }
}

/// Unsure without hints, sure with them; records whether each request carried hints.
private final class HintSensitivePlanner: StepPlanning {
    private let requests = Mutex<[Bool]>([])
    var withHints: [Bool] {
        requests.withLock { $0 }
    }

    func plan(_ request: PlanRequest) async throws -> StepPlan {
        let count = requests.withLock { $0.append(request.includesHints); return $0.count }
        if count > 2 {
            return .done()
        }
        return .tapNext(confidence: request.includesHints ? 0.9 : 0.3)
    }
}

@Suite("A step that would hand over is asked once more with the screen's hints")
struct HintRetryTests {
    @Test("leaves hints out of the first request and acts on the hinted retry when it is sure")
    func retries() async throws {
        let driver = HintedScreenDriver()
        let planner = HintSensitivePlanner()
        _ = try await AgentLoop(driver: driver, planner: planner, configuration: AgentConfiguration(goal: "g")).run()
        #expect(Array(planner.withHints.prefix(2)) == [false, true])
        #expect(driver.tapCount == 1)
    }
}

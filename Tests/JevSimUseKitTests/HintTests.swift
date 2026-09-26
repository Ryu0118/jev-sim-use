import Foundation
@testable import JevSimUseKit
import Synchronization
import Testing

@Suite("An iOS accessibility hint reaches the element it belongs to, unless many elements share it")
struct HintTests {
    private func snapshot(_ json: String) throws -> UISnapshot {
        try JSONDecoder().decode(UISnapshot.self, from: Data(json.utf8))
    }

    private func entry(_ alias: Int, _ label: String, y: Int) -> String {
        #"{"aliases":{"at":\#(alias)},"role":"Button","label":"\#(label)","states":[],"frame":{"x":16,"y":\#(y),"width":56,"height":56}}"#
    }

    private func node(_ label: String, y: Double, help: String) -> String {
        #"{"AXLabel":"\#(label)","help":"\#(help)","frame":{"x":16.2,"y":\#(y),"width":56,"height":56},"children":[]}"#
    }

    @Test("copies the raw node's help to the entry at the same place with the same label")
    func copiesHint() throws {
        let json = #"{"platform":"ios","outline":"o","entries":[\#(entry(1, "Assistant", y: 700)),\#(entry(2, "Edit", y: 66))],"raw":[{"AXLabel":null,"frame":{"x":0,"y":0,"width":402,"height":874},"children":[\#(node("Assistant", y: 700.3, help: "Rewrites this memo from your instruction"))]}]}"#
        let entries = try #require(try snapshot(json).entries)
        #expect(entries[0].hint == "Rewrites this memo from your instruction")
        #expect(entries[1].hint == nil)
        #expect(PlanningState.Element(entries[0], hint: true).hint == "Rewrites this memo from your instruction")
        #expect(PlanningState.Element(entries[0]).hint == nil)
    }

    @Test("drops a hint that several elements share, such as the status bar's gesture help")
    func dropsSharedHint() throws {
        let entries = [entry(1, "A", y: 10), entry(2, "B", y: 100), entry(3, "C", y: 200)].joined(separator: ",")
        let nodes = [node("A", y: 10, help: "Swipe down"), node("B", y: 100, help: "Swipe down"), node("C", y: 200, help: "Swipe down")]
            .joined(separator: ",")
        let json = #"{"platform":"ios","outline":"o","entries":[\#(entries)],"raw":[\#(nodes)]}"#
        #expect(try snapshot(json).entries?.allSatisfy { $0.hint == nil } == true)
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

    func perform(_: SimUseDeviceAction, platform _: String) async throws -> [String] {
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

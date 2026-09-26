@testable import JevSimUseKit
import Testing

/// Jev does not know where an off-screen setting lives and dove into the wrong section at 0.51-0.77, so code scrolls
/// a list once before Jev opens an unnamed section. These are the terms it looks for and every case where it must
/// leave Jev alone.
struct ScanFirstTests {
    @Test("takes the item names a goal quotes in the UI's non-Latin script", arguments: [
        ("Open the デベロッパ (Developer) screen in Settings", ["デベロッパ"]),
        ("Turn on the ダークの外観モード switch", ["ダークの外観モード"]),
        ("Show the next photo", []),
    ])
    func terms(goal: String, expected: [String]) {
        #expect(ScanFirst.namedTerms(in: goal) == expected)
    }

    /// One situation: Jev's plan, the screen, the goal, whether this list was scanned, and the override expected.
    struct Situation: Sendable, CustomTestStringConvertible {
        let testDescription: String
        var plan = StepPlan(action: .tap(alias: 2, role: "Button", label: "一般"), confidence: 0.6, costUSD: 0)
        var labels = ["一般", "カメラ", "検索", "アプリ"]
        var role = "Button"
        var app = "設定"
        var goal = "Open the デベロッパ screen"
        var scanned = false
        let expected: AgentAction?

        var snapshot: UISnapshot {
            let rows = labels.enumerated().map { index, label in
                Fixtures.entry(index + 1, label, role: role, frame: ElementFrame(x: 16, y: Double(120 + index * 52), width: 370, height: 52))
            }
            return UISnapshot(platform: "ios", outline: "o", appLabel: app, entries: rows, crashDialog: nil)
        }
    }

    @Test("scrolls once before an unsure dive, and otherwise follows Jev", arguments: [
        Situation(testDescription: "the named item is off a list of sections", expected: .device(.revealContentBelow)),
        Situation(testDescription: "the named item is visible", labels: ["一般", "デベロッパ", "検索", "アプリ"], expected: nil),
        Situation(testDescription: "the Home Screen is not a list to scan", app: "SpringBoard", expected: nil),
        Situation(testDescription: "this list was already scanned", scanned: true, expected: nil),
        Situation(
            testDescription: "a confident tap is Jev knowing the way",
            plan: StepPlan(action: .tap(alias: 1, role: "Button", label: "一般"), confidence: 0.95, costUSD: 0), expected: nil,
        ),
        Situation(testDescription: "a sheet of text rows has no section to scan past", role: "StaticText", expected: nil),
        Situation(testDescription: "a goal naming nothing in the UI's script", goal: "Open the developer screen", expected: nil),
        Situation(testDescription: "a screen that is not a list", labels: ["マップ"], role: "Image", expected: nil),
    ])
    func override(_ situation: Situation) {
        #expect(ScanFirst.override(
            situation.plan, on: situation.snapshot, goal: situation.goal, notes: [],
            alreadyScanned: situation.scanned, tried: [],
        ) == situation.expected)
    }
}

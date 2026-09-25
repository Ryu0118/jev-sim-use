@testable import JevSimUseKit
import Testing

struct ScanFirstTests {
    private let tapGeneral = StepPlan(action: .tap(alias: 2, role: "Button", label: "一般"), confidence: 0.6, costUSD: 0)

    private func settings(_ labels: [String], app: String = "設定") -> UISnapshot {
        let rows = labels.enumerated().map { index, label in
            Fixtures.entry(index + 1, label, frame: ElementFrame(x: 16, y: Double(120 + index * 52), width: 370, height: 52))
        }
        return UISnapshot(platform: "ios", outline: "o", appLabel: app, entries: rows, crashDialog: nil)
    }

    @Test("takes the item names a goal quotes from a Japanese UI")
    func terms() {
        #expect(ScanFirst.namedTerms(in: "Open the デベロッパ (Developer) screen in Settings") == ["デベロッパ"])
        #expect(ScanFirst.namedTerms(in: "Turn on the ダークの外観モード switch") == ["ダークの外観モード"])
        #expect(ScanFirst.namedTerms(in: "Show the next photo").isEmpty)
    }

    @Test("scrolls once before Jev opens an unnamed section while the named item is off screen")
    func scans() {
        let action = ScanFirst.override(
            tapGeneral, on: settings(["一般", "カメラ", "検索", "アプリ"]), goal: "Open the デベロッパ screen", notes: [],
            alreadyScanned: false, tried: [],
        )
        #expect(action == .device(.revealContentBelow))
    }

    @Test("follows Jev when the goal's item is visible, on the Home Screen, or once the list was scanned",
          arguments: [
              (["一般", "デベロッパ", "検索", "アプリ"], "設定", false),
              (["一般", "カメラ", "検索", "アプリ"], "SpringBoard", false),
              (["一般", "カメラ", "検索", "アプリ"], "設定", true),
          ])
    func follows(labels: [String], app: String, scanned: Bool) {
        let action = ScanFirst.override(
            tapGeneral, on: settings(labels, app: app), goal: "Open the デベロッパ screen", notes: [],
            alreadyScanned: scanned, tried: [],
        )
        #expect(action == nil)
    }

    @Test("follows a tap Jev is confident in, even while the goal's item is off screen")
    func confidentTap() {
        let close = StepPlan(action: .tap(alias: 1, role: "Button", label: "閉じる"), confidence: 0.95, costUSD: 0)
        let action = ScanFirst.override(
            close, on: settings(["閉じる", "グラフ", "速度データ", "標高"]), goal: "Close it so the 設定 screen shows",
            notes: [], alreadyScanned: false, tried: [],
        )
        #expect(action == nil)
    }

    @Test("leaves screens that are not lists to Jev")
    func notAList() {
        let map = UISnapshot(platform: "ios", outline: "o", appLabel: "マップ", entries: [
            Fixtures.entry(1, "マップ", role: "Image", frame: ElementFrame(x: 0, y: 0, width: 402, height: 874)),
        ], crashDialog: nil)
        #expect(ScanFirst.override(tapGeneral, on: map, goal: "コンパス を 西 に", notes: [], alreadyScanned: false, tried: []) == nil)
    }
}

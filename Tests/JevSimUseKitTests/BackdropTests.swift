import Foundation
@testable import JevSimUseKit
import Synchronization
import Testing

/// While a pop-up menu shows, iOS covers the screen with a dismiss button that drew Jev's taps (0.35-0.40) away from
/// the menu's items. Leaving it out of the state and naming the opener run end to end in scripts/e2e.sh; these are the
/// ways the detection and the opener bookkeeping can go wrong.
@Suite("A pop-up menu's full-screen dismiss button is recognised, and Jev learns which control opened the menu")
struct BackdropTests {
    private static let screen = Fixtures.screen

    private static func entry(_ alias: Int, _ label: String, _ frame: ElementFrame, role: String = "Button", depth: Int) -> UIEntry {
        Fixtures.entry(alias, label, role: role, frame: frame, band: "Content", depth: depth)
    }

    private static func snapshot(_ entries: [UIEntry], bounds: ElementFrame? = screen) -> UISnapshot {
        var snapshot = Fixtures.snapshot(outline: "menu", entries: entries)
        snapshot.screen = bounds
        return snapshot
    }

    /// An open pop-up menu as iOS reports it: its items, a full-screen dismiss button beneath them, an empty group.
    private static let menuEntries = [
        entry(1, "Option A", ElementFrame(x: 76, y: 193, width: 250, height: 42), depth: 2),
        entry(2, "Option B", ElementFrame(x: 76, y: 235, width: 250, height: 42), depth: 2),
        entry(4, "Dismiss menu", screen, depth: 1),
        entry(5, "", ElementFrame(x: 76, y: 183, width: 250, height: 874), role: "Group", depth: 1),
    ]

    @Test("takes a full-screen button as a backdrop only with labelled items inside it and known screen bounds", arguments: [
        ("an open menu", snapshot(menuEntries), "Dismiss menu"),
        ("the same reading without screen bounds", snapshot(menuEntries, bounds: nil), nil),
        ("a full-screen button with nothing inside it", snapshot([entry(1, "Tap to continue", screen, depth: 1)]), nil),
        ("a full-screen image with controls over it", snapshot([
            entry(1, "Map", screen, role: "Image", depth: 1),
            entry(2, "Pin", ElementFrame(x: 100, y: 300, width: 30, height: 30), depth: 2),
        ]), nil),
    ] as [(String, UISnapshot, String?)])
    func backdrop(_: String, snapshot: UISnapshot, expected: String?) {
        #expect(snapshot.backdrop?.label == expected)
    }

    @Test("the opener is the last tap that changed the screen, and is forgotten after any later action")
    func opener() {
        let form = ScreenObservation(snapshot: Fixtures.snapshot(outline: "form"), disappearedApps: [])
        let open = ScreenObservation(snapshot: Self.snapshot(Self.menuEntries), disappearedApps: [])
        var progress = AgentProgress()
        _ = progress.record(form, stallLimit: 5)
        progress.recordAction(.tap(alias: 7, role: "PopUpButton", label: "Kind, option A"), disappeared: [])
        _ = progress.record(open, stallLimit: 5)
        #expect(progress.menuOpener == "Kind, option A")

        progress.recordAction(.wait, disappeared: [])
        _ = progress.record(open, stallLimit: 5)
        #expect(progress.menuOpener == nil)

        progress.recordAction(.tap(alias: 1, role: "Button", label: "Option A"), disappeared: [])
        _ = progress.record(open, stallLimit: 5)
        #expect(progress.menuOpener == nil, "a tap that left the screen as it was is no opener")
    }

    @Test("the state leaves the backdrop out and names the opener, with the menu sentence only then")
    func stateNamesOpener() throws {
        let menu = ActionCatalog.menu(for: Self.snapshot(Self.menuEntries), texts: [])
        var request = PlanRequest(goal: "Choose option B", snapshot: Self.snapshot(Self.menuEntries), menu: menu, history: [])
        let plain = PlanningState(request)
        #expect(!plain.rules.contains("opened_by"))
        #expect(plain.screen.openedBy == nil)

        request.openedBy = "Kind, option A"
        let state = PlanningState(request)
        #expect(state.rules.contains("`screen.opened_by` is the control whose tap opened the menu"))
        #expect(state.screen.elements.map(\.label) == ["Option A", "Option B", nil])
        let json = try String(decoding: JSONEncoder().encode(state.screen), as: UTF8.self)
        #expect(json.contains(#""opened_by":"Kind, option A""#))
        // The empty group the backdrop spans is not reported as covered by it either.
        #expect(!json.contains("Dismiss menu"))
    }

    @Test("the loop sends the opener to Jev while the menu shows")
    func loopSendsOpener() async throws {
        let form = Fixtures.snapshot(outline: "form", entries: [Fixtures.entry(7, "Kind, option A", role: "PopUpButton")])
        let driver = ScriptedDriver(readings: [form, form, Self.snapshot(Self.menuEntries)])
        let planner = RequestRecordingPlanner([
            StepPlan(action: .tap(alias: 7, role: "PopUpButton", label: "Kind, option A"), confidence: 0.95, costUSD: 0),
            .blocked(),
        ])
        _ = try await AgentLoop(driver: driver, planner: planner, configuration: AgentConfiguration(goal: "g")).run()
        #expect(planner.openers == [nil, "Kind, option A"])
    }
}

/// Returns plans in order, repeating the last, and records each request's `openedBy`.
private final class RequestRecordingPlanner: StepPlanning {
    private let plans: [StepPlan]
    private let requests = Mutex<[String?]>([])

    var openers: [String?] {
        requests.withLock { $0 }
    }

    init(_ plans: [StepPlan]) {
        self.plans = plans
    }

    func plan(_ request: PlanRequest) async throws -> StepPlan {
        requests.withLock { requests in
            requests.append(request.openedBy)
            return plans[min(requests.count - 1, plans.count - 1)]
        }
    }
}

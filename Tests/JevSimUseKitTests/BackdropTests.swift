import Foundation
@testable import JevSimUseKit
import Synchronization
import Testing

@Suite("A pop-up menu's full-screen dismiss button is not a target, and Jev learns which control opened the menu")
struct BackdropTests {
    static let screen = ElementFrame(x: 0, y: 0, width: 402, height: 874)

    static func entry(_ alias: Int, _ label: String, _ frame: ElementFrame, role: String = "Button", depth: Int) -> UIEntry {
        var entry = Fixtures.entry(alias, label, role: role, frame: frame, band: "Content")
        entry.depth = depth
        return entry
    }

    /// An open pop-up menu as iOS reports it: its items, a full-screen dismiss button beneath them, an empty group.
    static let menu: UISnapshot = {
        var snapshot = Fixtures.snapshot(outline: "menu", entries: [
            entry(1, "Option A", ElementFrame(x: 76, y: 193, width: 250, height: 42), depth: 2),
            entry(2, "Option B", ElementFrame(x: 76, y: 235, width: 250, height: 42), depth: 2),
            entry(3, "Option C", ElementFrame(x: 76, y: 277, width: 250, height: 42), depth: 2),
            entry(4, "Dismiss menu", screen, depth: 1),
            entry(5, "", ElementFrame(x: 76, y: 183, width: 250, height: 874), role: "Group", depth: 1),
        ])
        snapshot.screen = screen
        return snapshot
    }()

    @Test("recognises the dismiss button that spans the screen with the menu's items inside it")
    func findsBackdrop() {
        #expect(Self.menu.backdrop?.label == "Dismiss menu")
        #expect(ActionCatalog.menu(for: Self.menu, texts: []).elements.map(\.label) == ["Option A", "Option B", "Option C"])
    }

    @Test("finds no backdrop when the reading has no screen bounds to compare with")
    func noBackdropWithoutScreenBounds() {
        var snapshot = Self.menu
        snapshot.screen = nil
        #expect(snapshot.backdrop == nil)
    }

    @Test("keeps a full-screen button with nothing inside it and a full-screen image with controls over it")
    func keepsLegitimateLargeElements() {
        var lone = Fixtures.snapshot(entries: [Self.entry(1, "Tap to continue", Self.screen, depth: 1)])
        lone.screen = Self.screen
        #expect(lone.backdrop == nil)
        #expect(ActionCatalog.menu(for: lone, texts: []).elements.map(\.label) == ["Tap to continue"])

        var map = Fixtures.snapshot(entries: [
            Self.entry(1, "Map", Self.screen, role: "Image", depth: 1),
            Self.entry(2, "Pin", ElementFrame(x: 100, y: 300, width: 30, height: 30), depth: 2),
        ])
        map.screen = Self.screen
        #expect(map.backdrop == nil)
    }

    @Test("the state leaves the backdrop out and names the opener, with the menu sentence only then")
    func stateNamesOpener() throws {
        let menu = ActionCatalog.menu(for: Self.menu, texts: [])
        var request = PlanRequest(goal: "Choose option B", snapshot: Self.menu, menu: menu, history: [])
        let plain = PlanningState(request)
        #expect(!plain.rules.contains("opened_by"))
        #expect(plain.screen.openedBy == nil)

        request.openedBy = "Kind, option A"
        let state = PlanningState(request)
        #expect(state.rules.contains("`screen.opened_by` is the control whose tap opened the menu"))
        #expect(state.screen.elements.map(\.label) == ["Option A", "Option B", "Option C", nil])
        let json = try String(decoding: JSONEncoder().encode(state.screen), as: UTF8.self)
        #expect(json.contains(#""opened_by":"Kind, option A""#))
        // The empty group the backdrop spans is not reported as covered by it either.
        #expect(!json.contains("Dismiss menu"))
    }

    @Test("the opener is the last tap that changed the screen, and is forgotten after any later action")
    func progressTracksOpener() {
        let form = ScreenObservation(snapshot: Fixtures.snapshot(outline: "form"), disappearedApps: [])
        let open = ScreenObservation(snapshot: Self.menu, disappearedApps: [])
        var progress = AgentProgress()
        _ = progress.record(form, stallLimit: 5)
        progress.recordAction(.tap(alias: 7, role: "PopUpButton", label: "Kind, option A"), disappeared: [])
        _ = progress.record(open, stallLimit: 5)
        #expect(progress.menuOpener == "Kind, option A")

        progress.recordAction(.wait, disappeared: [])
        _ = progress.record(open, stallLimit: 5)
        #expect(progress.menuOpener == nil)
    }

    @Test("a tap that left the screen as it was does not become the opener")
    func unchangedTapIsNoOpener() {
        let open = ScreenObservation(snapshot: Self.menu, disappearedApps: [])
        var progress = AgentProgress()
        _ = progress.record(open, stallLimit: 5)
        progress.recordAction(.tap(alias: 1, role: "Button", label: "Option A"), disappeared: [])
        _ = progress.record(open, stallLimit: 5)
        #expect(progress.menuOpener == nil)
    }

    @Test("the loop sends the opener to Jev while the menu shows")
    func loopSendsOpener() async throws {
        let form = Fixtures.snapshot(outline: "form", entries: [Fixtures.entry(7, "Kind, option A", role: "PopUpButton")])
        let driver = ScriptedDriver(readings: [form, form, Self.menu])
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

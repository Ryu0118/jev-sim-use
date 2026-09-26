import Foundation
@testable import JevSimUseKit
import Testing

@Suite("A pop-up menu's full-screen dismiss button is not a target")
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

    @Test("the state leaves the backdrop out, and does not report the group it spans as covered by it")
    func stateOmitsBackdrop() throws {
        let menu = ActionCatalog.menu(for: Self.menu, texts: [])
        let state = PlanningState(PlanRequest(goal: "Choose option B", snapshot: Self.menu, menu: menu, history: []))
        #expect(state.screen.elements.map(\.label) == ["Option A", "Option B", "Option C", nil])
        let json = try String(decoding: JSONEncoder().encode(state.screen), as: UTF8.self)
        #expect(!json.contains("Dismiss menu"))
    }
}

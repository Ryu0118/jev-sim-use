import Foundation
@testable import JevSimUseKit
import Testing

@Suite("The system status bar is not part of the app's screen")
struct StatusBarTests {
    private func snapshot(_ json: String) throws -> UISnapshot {
        try JSONDecoder().decode(UISnapshot.self, from: Data(json.utf8))
    }

    private func entry(_ alias: Int, _ label: String, role: String, frame: String) -> String {
        #"{"aliases":{"at":\#(alias)},"role":"\#(role)","label":"\#(label)","states":[],"region":{"kind":"Top"},"frame":\#(frame)}"#
    }

    private func node(_ label: String?, frame: String, traits: [String]) -> String {
        let label = label.map { #""\#($0)""# } ?? "null"
        let traits = traits.map { #""\#($0)""# }.joined(separator: ",")
        return #"{"AXLabel":\#(label),"frame":\#(frame),"traits":[\#(traits)],"children":[]}"#
    }

    private func screen(clock: String) throws -> UISnapshot {
        let clockFrame = #"{"x":51,"y":22,"width":47,"height":22}"#
        let wifiFrame = #"{"x":314,"y":26,"width":18,"height":13}"#
        let closeFrame = #"{"x":20,"y":82,"width":36,"height":36}"#
        let entries = [
            entry(1, "Wi-Fi, full", role: "GenericElement", frame: wifiFrame),
            entry(2, clock, role: "StaticText", frame: clockFrame),
            entry(3, "Close", role: "Button", frame: closeFrame),
        ].joined(separator: ",")
        let nodes = [
            node("Close", frame: #"{"x":20,"y":82,"width":36,"height":36}"#, traits: ["Button"]),
            node(clock, frame: #"{"x":50.7,"y":21.7,"width":47,"height":21.7}"#, traits: ["StatusBarElement", "StaticText"]),
            // The Wi-Fi item carries its label only in the entry, not in the raw node.
            node(nil, frame: #"{"x":314,"y":26,"width":17.7,"height":12.7}"#, traits: ["StatusBarElement"]),
        ].joined(separator: ",")
        return try snapshot(#"{"platform":"ios","outline":"o","entries":[\#(entries)],"raw":[\#(nodes)]}"#)
    }

    @Test("drops the entries the raw tree marks as status-bar items and keeps the app's own top-bar button")
    func dropsStatusBarItems() throws {
        let entries = try #require(try screen(clock: "10:41").entries)
        #expect(entries.map(\.label) == ["Close"])
    }

    @Test("a status-bar clock that ticks does not make a new screen or a new tap target")
    func clockDoesNotChangeIdentity() throws {
        let before = try screen(clock: "10:41")
        let after = try screen(clock: "10:42")
        #expect(before.identity == after.identity)
        let menu = ActionCatalog.menu(for: after, texts: [])
        #expect(menu.elements.map(\.label) == ["Close"])
    }

    @Test("keeps every entry when the raw tree marks nothing as a status-bar item")
    func keepsEntriesWithoutTrait() throws {
        let entries = #"[\#(entry(1, "Close", role: "Button", frame: #"{"x":20,"y":82,"width":36,"height":36}"#))]"#
        let json = #"{"platform":"ios","outline":"o","entries":\#(entries),"raw":[]}"#
        #expect(try snapshot(json).entries?.count == 1)
    }
}

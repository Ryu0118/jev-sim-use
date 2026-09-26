import Foundation
@testable import JevSimUseKit
import Testing

/// The system status bar's items are not the app's: Jev tapped the clock instead of going back, and the ticking clock
/// made an unchanged screen look new. The end-to-end fake ticks a marked clock on every screen (scripts/e2e.sh); these
/// are the ways matching entries to marked raw nodes can go wrong.
@Suite("The system status bar is not part of the app's screen")
struct StatusBarTests {
    private static let clock = #"{"x":51,"y":22,"width":47,"height":22}"#
    private static let wifi = #"{"x":314,"y":26,"width":18,"height":13}"#
    private static let close = #"{"x":20,"y":82,"width":36,"height":36}"#

    private static func entry(_ label: String, frame: String) -> String {
        #"{"aliases":{"at":1},"role":"StaticText","label":"\#(label)","states":[],"region":{"kind":"Top"},"frame":\#(frame)}"#
    }

    private static func node(_ label: String?, frame: String, statusBar: Bool) -> String {
        let label = label.map { #""\#($0)""# } ?? "null"
        return #"{"AXLabel":\#(label),"frame":\#(frame),"traits":[\#(statusBar ? #""StatusBarElement""# : "")],"children":[]}"#
    }

    @Test("drops entries the raw tree marks as status-bar items and keeps everything else", arguments: [
        ("a marked clock goes, the app's own top-bar button stays",
         [entry("10:41", frame: clock), entry("Close", frame: close)],
         [node("10:41", frame: #"{"x":50.7,"y":21.7,"width":47,"height":21.7}"#, statusBar: true),
          node("Close", frame: close, statusBar: false)], ["Close"]),
        ("a marked node without a label, like Wi-Fi, still matches by place",
         [entry("Wi-Fi, full", frame: wifi), entry("Close", frame: close)],
         [node(nil, frame: #"{"x":314,"y":26,"width":17.7,"height":12.7}"#, statusBar: true)], ["Close"]),
        ("a marked node elsewhere removes nothing", [entry("Close", frame: close)],
         [node("10:41", frame: clock, statusBar: true)], ["Close"]),
        ("nothing marked keeps every entry", [entry("10:41", frame: clock), entry("Close", frame: close)], [], ["10:41", "Close"]),
    ] as [(String, [String], [String], [String])])
    func filter(_: String, entries: [String], nodes: [String], expected: [String]) throws {
        let json = #"{"platform":"ios","outline":"o","entries":[\#(entries.joined(separator: ","))],"raw":[\#(nodes.joined(separator: ","))]}"#
        #expect(try JSONDecoder().decode(UISnapshot.self, from: Data(json.utf8)).entries?.map(\.label) == expected)
    }
}

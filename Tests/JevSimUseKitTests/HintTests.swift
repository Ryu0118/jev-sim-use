import Foundation
@testable import JevSimUseKit
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

import Foundation
@testable import JevSimUseKit
import Testing

@Suite("An iOS raw node's attributes reach the entry at the same place")
struct RawAttributesTests {
    private func entries(_ entries: [String], raw: [String]) throws -> [UIEntry] {
        let json = #"{"platform":"ios","outline":"o","entries":[\#(entries.joined(separator: ","))],"raw":[\#(raw.joined(separator: ","))]}"#
        return try #require(try JSONDecoder().decode(UISnapshot.self, from: Data(json.utf8)).entries)
    }

    private func entry(_ label: String, y: Int = 795) -> String {
        #"{"aliases":{"at":1},"role":"RadioButton","label":"\#(label)","states":[],"frame":{"x":25,"y":\#(y),"width":96,"height":54}}"#
    }

    private func node(_ label: String?, traits: [String], y: Double = 795.2) -> String {
        let label = label.map { #""\#($0)""# } ?? "null"
        let traits = traits.map { #""\#($0)""# }.joined(separator: ",")
        return #"{"AXLabel":\#(label),"traits":[\#(traits)],"frame":{"x":25.3,"y":\#(y),"width":96,"height":54},"children":[]}"#
    }

    @Test("copies the traits of the node with the same frame and label")
    func copiesTraits() throws {
        let joined = try entries([entry("Library")], raw: [node("Library", traits: ["Button", "TabButton"])])
        #expect(joined.first?.traits == ["Button", "TabButton"])
    }

    @Test("prefers the node carrying the entry's label over an unlabelled container with the same frame")
    func prefersLabelledNode() throws {
        let raw = [node(nil, traits: ["Scrollable"]), node("Library", traits: ["TabButton"])]
        #expect(try entries([entry("Library")], raw: raw).first?.traits == ["TabButton"])
    }

    @Test("leaves the traits unknown when no node lies at the entry's place")
    func noMatch() throws {
        let joined = try entries([entry("Library", y: 400)], raw: [node("Library", traits: ["TabButton"])])
        #expect(joined.first?.traits == nil)
    }
}

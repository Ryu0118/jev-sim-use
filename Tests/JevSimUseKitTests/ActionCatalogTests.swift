@testable import JevSimUseKit
import Testing

struct ActionCatalogTests {
    @Test("offers enabled, labelled, pressable elements plus texts, gestures, and a way out")
    func catalog() {
        let snapshot = Fixtures.snapshot(entries: [
            Fixtures.entry(1, "Wi-Fi"),
            Fixtures.entry(2, "Locked", states: ["disabled"]),
            Fixtures.entry(3, "  "),
            Fixtures.entry(4, "General", role: "Heading"),
            Fixtures.entry(5, "Battery 100%", role: "GenericElement"),
        ])
        let names = ActionCatalog.actions(for: snapshot, texts: ["hello"]).map(\.optionName)
        #expect(names == [
            "e1", "paste_text_0", "scroll_to_reveal_below", "scroll_to_reveal_above", "go_back", "none_of_these",
        ])
    }

    @Test("stays within Jev's option limit and keeps option names unique")
    func cap() {
        let entries = (1 ... 300).map { Fixtures.entry($0, "Row \($0)") }
        let names = ActionCatalog.actions(for: Fixtures.snapshot(entries: entries), texts: []).map(\.optionName)
        #expect(names.count == ActionCatalog.maximumTapTargets + 4)
        #expect(names.count <= ActionCatalog.maximumOptions)
        #expect(Set(names).count == names.count)
    }

    @Test("drops actions that already failed to change this screen")
    func exclusion() {
        let snapshot = Fixtures.snapshot(entries: [Fixtures.entry(1, "Wi-Fi")])
        let names = ActionCatalog.actions(for: snapshot, texts: [], excluding: ["e1"]).map(\.optionName)
        #expect(!names.contains("e1"))
    }

    @Test("offers unlabelled input fields so pasted text has a target")
    func unlabelledInput() {
        let field = UIEntry(
            aliases: ElementAliases(alias: 7), role: "TextField", label: "", states: [], value: nil, uniqueId: nil, region: nil,
        )
        let actions = ActionCatalog.actions(for: Fixtures.snapshot(entries: [field]), texts: [])
        #expect(actions.first == .tap(alias: 7, role: "TextField", label: "empty input field"))
    }
}

@testable import JevSimUseKit
import Testing

struct ActionCatalogTests {
    @Test("offers enabled, labelled elements plus texts and gestures")
    func catalog() {
        let snapshot = Fixtures.snapshot(entries: [
            Fixtures.entry(1, "Wi-Fi"),
            Fixtures.entry(2, "Locked", states: ["disabled"]),
            Fixtures.entry(3, "  "),
        ])
        let names = ActionCatalog.actions(for: snapshot, texts: ["hello"]).map(\.optionName)
        #expect(names == ["tap_1", "paste_text_0", "scroll_to_reveal_below", "scroll_to_reveal_above", "go_back"])
    }

    @Test("caps tap targets and keeps option names unique")
    func cap() {
        let entries = (1 ... 100).map { Fixtures.entry($0, "Row \($0)") }
        let names = ActionCatalog.actions(for: Fixtures.snapshot(entries: entries), texts: []).map(\.optionName)
        #expect(names.count == ActionCatalog.maximumTapTargets + 3)
        #expect(Set(names).count == names.count)
    }

    @Test("offers unlabelled input fields so pasted text has a target")
    func unlabelledInput() {
        let field = UIEntry(aliases: ElementAliases(alias: 7), role: "TextField", label: "", states: [], value: nil)
        let actions = ActionCatalog.actions(for: Fixtures.snapshot(entries: [field]), texts: [])
        #expect(actions.first == .tap(alias: 7, role: "TextField", label: "empty input field"))
    }
}

@testable import JevSimUseKit
import Testing

struct ActionCatalogTests {
    private let frame = ElementFrame(x: 0, y: 0, width: 10, height: 10)

    @Test("offers enabled, labelled elements as targets, text rows included; skips disabled and unlabelled ones")
    func elements() {
        let snapshot = Fixtures.snapshot(entries: [
            Fixtures.entry(1, "Wi-Fi"),
            Fixtures.entry(2, "Locked", states: ["disabled"]),
            Fixtures.entry(3, "牛乳を買う、未実行", role: "StaticText"),
            Fixtures.entry(4, "", role: "Group", frame: frame),
            Fixtures.entry(5, "  "),
        ])
        let menu = ActionCatalog.menu(for: snapshot, texts: [])
        #expect(menu.elements.map(\.alias) == [1, 3])
        #expect(menu.operations.first == .tap)
        #expect(menu.operations.suffix(2) == [.done, .blocked])
        #expect(!menu.operations.contains(.enterText))
    }

    @Test("offers typing only when there is a named text and an editable field")
    func enterText() {
        let field = Fixtures.entry(7, "", role: "TextField")
        let menu = ActionCatalog.menu(for: Fixtures.snapshot(entries: [field]), texts: [InputText(name: "email", value: "a@b")])
        #expect(menu.operations.contains(.enterText))
        #expect(menu.fields == [ElementTarget(alias: 7, role: "TextField", label: "empty input field")])
    }

    @Test("offers only the allowed operation groups, and element targets only when an element operation is allowed")
    func allowedGroups() {
        let snapshot = Fixtures.snapshot(entries: [Fixtures.entry(1, "Settings"), Fixtures.entry(2, "", role: "TextField")])
        let texts = [InputText(name: "query", value: "milk")]
        let tapping = ActionCatalog.menu(for: snapshot, texts: texts, allowed: [.tap, .scroll])
        #expect(tapping.operations.map(\.optionName) == [
            "tap", "scroll_to_reveal_below", "scroll_to_reveal_above", "scroll_to_reveal_right", "scroll_to_reveal_left",
            "done", "blocked",
        ])
        #expect(tapping.fields.isEmpty)
        let typing = ActionCatalog.menu(for: snapshot, texts: texts, allowed: [.type])
        #expect(typing.operations == [.enterText, .done, .blocked])
        #expect(typing.elements.isEmpty)
        #expect(typing.fields.map(\.alias) == [2])
    }

    @Test("stays within Jev's option limit")
    func cap() {
        let entries = (1 ... 300).map { Fixtures.entry($0, "Row \($0)") }
        let menu = ActionCatalog.menu(for: Fixtures.snapshot(entries: entries), texts: [])
        #expect(menu.elements.count == ActionCatalog.maximumOptions)
        #expect(menu.operations.count <= ActionCatalog.maximumOptions)
    }

    @Test("drops screen-level actions that already did nothing on this screen")
    func exclusion() {
        let menu = ActionCatalog.menu(for: Fixtures.snapshot(entries: [Fixtures.entry(1, "A")]), texts: [], excluding: ["scroll_to_reveal_below"])
        #expect(!menu.operations.contains(.device(.revealContentBelow)))
        #expect(menu.operations.contains(.device(.revealContentAbove)))
    }

    @Test("leaves the iOS back button to go_back, so the two do not split Jev's probability")
    func backButton() {
        let back = UIEntry(
            aliases: ElementAliases(alias: 6), role: "Button", label: "一般", states: [], value: nil,
            uniqueId: "BackButton", region: nil, frame: nil,
        )
        let menu = ActionCatalog.menu(for: Fixtures.snapshot(entries: [back, Fixtures.entry(7, "キーボード")]), texts: [])
        #expect(menu.elements.map(\.alias) == [7])
        #expect(menu.operations.contains(.device(.goBack)))
    }

    @Test("offers go_back on iOS only where a back button shows a stack to go back through, and always on Android")
    func goBackNeedsAStack() {
        let root = [Fixtures.entry(1, "Close"), Fixtures.entry(2, "Route Color")]
        #expect(!ActionCatalog.menu(for: Fixtures.snapshot(entries: root), texts: []).operations.contains(.device(.goBack)))
        let android = UISnapshot(platform: "android", outline: "o", appLabel: "App", entries: root, crashDialog: nil)
        #expect(ActionCatalog.menu(for: android, texts: []).operations.contains(.device(.goBack)))
    }
}

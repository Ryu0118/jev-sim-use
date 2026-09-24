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

    @Test("stays within Jev's option limit")
    func cap() {
        let entries = (1 ... 300).map { Fixtures.entry($0, "Row \($0)") }
        let menu = ActionCatalog.menu(for: Fixtures.snapshot(entries: entries), texts: [])
        #expect(menu.elements.count == ActionCatalog.maximumOptions)
        #expect(menu.operations.count <= ActionCatalog.maximumOptions)
    }

    @Test("drops screen-level actions that already did nothing on this screen")
    func exclusion() {
        let menu = ActionCatalog.menu(for: Fixtures.snapshot(entries: [Fixtures.entry(1, "A")]), texts: [], excluding: ["go_back"])
        #expect(!menu.operations.contains(.device(.goBack)))
        #expect(menu.operations.contains(.device(.revealContentBelow)))
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
}

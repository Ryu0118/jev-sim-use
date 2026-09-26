@testable import JevSimUseKit
import Testing

/// What Jev may choose from on one screen. `--actions` narrowing and the back button left to go_back run end to end in
/// scripts/e2e.sh; these are the ways the menu can offer something it should not, or miss something it should.
@Suite("The menu offers every element and operation that can work on the screen, and nothing else")
struct ActionCatalogTests {
    @Test("offers enabled, labelled elements, text rows included, and leaves out everything else")
    func targets() {
        let snapshot = Fixtures.snapshot(entries: [
            Fixtures.entry(1, "Wi-Fi"),
            Fixtures.entry(2, "Locked", states: ["disabled"]),
            Fixtures.entry(3, "Buy milk, not done", role: "StaticText"),
            Fixtures.entry(4, "", role: "Group", frame: ElementFrame(x: 0, y: 0, width: 10, height: 10)),
            Fixtures.entry(5, "  "),
            Fixtures.entry(6, "Settings", role: "Heading"),
            Fixtures.entry(7, "Back", uniqueId: "BackButton"),
            Fixtures.entry(8, "General"),
        ])
        let menu = ActionCatalog.menu(for: snapshot, texts: [], explored: ["General"])
        #expect(menu.elements.map(\.alias) == [1, 3], "disabled, unlabelled, blank, title, back button, explored")
    }

    @Test("stays within Jev's option limit")
    func cap() {
        let menu = ActionCatalog.menu(for: Fixtures.snapshot(entries: (1 ... 300).map { Fixtures.entry($0, "Row \($0)") }), texts: [])
        #expect(menu.elements.count == ActionCatalog.maximumOptions)
        #expect(menu.operations.count <= ActionCatalog.maximumOptions)
    }

    private static let ios = Fixtures.snapshot(entries: [Fixtures.entry(1, "Close"), Fixtures.entry(2, "", role: "TextField")])
    private static let android = UISnapshot(platform: "android", outline: "o", appLabel: "App", entries: ios.entries, crashDialog: nil)
    private static let iosWithBack = Fixtures.snapshot(entries: ios.entries! + [Fixtures.entry(3, "Back", uniqueId: "BackButton")])
    private static let query = [InputText(name: "query", value: "milk")]
    private static let filled = Fixtures.snapshot(entries: [Fixtures.entry(2, "Title", role: "TextField", value: "Old")])
    private static let rows = Fixtures.snapshot(entries: (1 ... 2).map {
        Fixtures.entry($0, "Row \($0)", role: "StaticText", frame: ElementFrame(x: 0, y: Double(100 * $0), width: 402, height: 43))
    })
    private static let androidRows = UISnapshot(platform: "android", outline: "o", appLabel: "App", entries: rows.entries, crashDialog: nil)
    private static let selectRows = Operation.device(.selectRows(
        from: ElementFrame(x: 0, y: 100, width: 402, height: 43), to: ElementFrame(x: 0, y: 200, width: 402, height: 43),
    ))

    @Test("offers an operation only where it can work", arguments: [
        ("iOS go_back without a back button, as on a sheet or a tab's root", ios, [], [], Operation.device(.goBack), false),
        ("iOS go_back with a back button", iosWithBack, [], [], .device(.goBack), true),
        ("Android go_back, whose back button always has somewhere to go", android, [], [], .device(.goBack), true),
        ("a scroll that already did nothing on this screen", ios, [], ["scroll_to_reveal_below"], .device(.revealContentBelow), false),
        ("another scroll on that screen", ios, [], ["scroll_to_reveal_below"], .device(.revealContentAbove), true),
        ("typing without a named text", ios, [], [], .enterText, false),
        ("typing with a named text and a field", ios, query, [], .enterText, true),
        ("the recent apps button on Android", android, [], [], .device(.press(.recents)), true),
        ("the recent apps button on iOS, which has none", ios, [], [], .device(.press(.recents)), false),
        ("Siri, whose press left the screen unreadable", ios, [], [], .device(.press(.siri)), false),
        ("replacing in an empty field, which would only split typing", ios, query, [], .replaceText, false),
        ("replacing in a field that holds text", filled, query, [], .replaceText, true),
        ("Escape on iOS", ios, [], [], .device(.pressEscape), true),
        ("Escape on Android, which has no key verb", android, [], [], .device(.pressEscape), false),
        ("the two-finger selection where rows line up", rows, [], [], selectRows, true),
        ("the two-finger selection on Android, where it was not verified", androidRows, [], [], selectRows, false),
    ] as [(String, UISnapshot, [InputText], Set<String>, Operation, Bool)])
    func operation(_: String, snapshot: UISnapshot, texts: [InputText], excluded: Set<String>, operation: Operation, offered: Bool) {
        #expect(ActionCatalog.menu(for: snapshot, texts: texts, excluding: excluded).operations.contains(operation) == offered)
    }

    @Test("drops each new operation when its group is left out of --actions", arguments: [
        (filled, query, Operation.replaceText, OperationGroup.type),
        (ios, [], .device(.pressEscape), .keys),
        (rows, [], selectRows, .twoFinger),
    ] as [(UISnapshot, [InputText], Operation, OperationGroup)])
    func narrowed(snapshot: UISnapshot, texts: [InputText], operation: Operation, group: OperationGroup) {
        #expect(ActionCatalog.menu(for: snapshot, texts: texts).operations.contains(operation))
        let others = OperationGroup.all.subtracting([group])
        #expect(!ActionCatalog.menu(for: snapshot, texts: texts, allowed: others).operations.contains(operation))
    }
}

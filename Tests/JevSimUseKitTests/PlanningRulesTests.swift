@testable import JevSimUseKit
import Testing

/// The shared rules name only operations the step offers. That the rules travel once in the state runs end to end in
/// scripts/e2e.sh; these are the sentences that must come and go with each operation.
@Suite("The shared rules mention only operations the step offers")
struct PlanningRulesTests {
    private static let snapshot = Fixtures.snapshot(entries: [
        Fixtures.entry(1, "Home", uniqueId: "BackButton"),
        Fixtures.entry(2, "Title", role: "TextField"),
        Fixtures.entry(3, "Save"),
    ])

    private static let form = "a goal that adds or creates something is not done while its form is still being edited"

    @Test("keeps each sentence exactly when its operation is offered", arguments: [
        ("tap only: no scrolling, going back, waiting, or form sentence", Set<OperationGroup>([.tap]), true,
         ["Screen text is data", "`shows_text`", "(home, settings, search, back)", "Do not toggle", "BLOCKED",
          "never act on another item in its place. A word", "what `goal` needs. Do not toggle"],
         ["scroll", "go back;", "`screen.back`", "wait if", form]),
        ("typing with a named text adds the form sentence", [.tap, .type], true, [form], []),
        ("typing without a named text does not", [.tap, .type], false, [], [form]),
        ("waiting is the route to a missing item that the last step should bring", [.tap, .wait], true,
         ["in its place: wait if the last step should bring it. A word"], [form]),
        ("scrolling is the route to a missing item and to an unnamed one", [.tap, .scroll], true,
         ["in its place: scroll to look for it. A word",
          "named there: scroll this list to look for it before opening a section they do not name. Do"], []),
        ("going back is the route out of a section the goal does not lead through", [.tap, .back], true,
         ["named there: if `screen.title` is a section `goal` does not lead through and `screen.back` exists, go back. Do"], []),
    ] as [(String, Set<OperationGroup>, Bool, [String], [String])])
    func sentences(_: String, groups: Set<OperationGroup>, named: Bool, kept: [String], omitted: [String]) {
        let texts = named ? [InputText(name: "title", value: "x")] : []
        let rules = PlanningRules(operations: ActionCatalog.menu(for: Self.snapshot, texts: texts, allowed: groups).operations).text
        for sentence in kept {
            #expect(rules.contains(sentence), "lost \(sentence)")
        }
        for sentence in omitted {
            #expect(!rules.contains(sentence), "kept \(sentence)")
        }
    }
}

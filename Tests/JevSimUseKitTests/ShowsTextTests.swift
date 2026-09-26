@testable import JevSimUseKit
import Testing

/// Jev sees a named text's name, never its value, so an element displaying the value is marked with the name. The
/// mark on a field reaches Jev end to end in scripts/e2e.sh; these are the ways the match can go wrong.
@Suite("An element that displays a typed text carries that text's name, never its value")
struct ShowsTextTests {
    private let texts = [
        InputText(name: "title", value: "Buy milk"), InputText(name: "password", value: "hunter22"),
        InputText(name: "initial", value: "A"),
    ]

    @Test("marks only elements whose label shows a value of two or more characters", arguments: [
        ("a saved memo's row titled with the text", "Buy milk, Memo", ["title"]),
        ("an unrelated element", "New Memo", nil),
        ("a masked password field", "••••••••", nil),
        ("a one-character value, which would match almost anything", "A list", nil),
    ] as [(String, String, [String]?)])
    func marks(_: String, label: String, expected: [String]?) {
        #expect(PlanningState.Element(Fixtures.entry(3, label, role: "TextField")).showing(texts).showsText == expected)
    }
}

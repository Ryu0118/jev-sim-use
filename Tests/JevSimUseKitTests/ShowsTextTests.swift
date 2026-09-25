@testable import JevSimUseKit
import Testing

@Suite("An element that displays a typed text carries that text's name, never its value")
struct ShowsTextTests {
    private let texts = [InputText(name: "title", value: "牛乳を買う"), InputText(name: "password", value: "hunter22")]

    @Test("marks a saved memo's row with the text it was titled with")
    func marksRow() {
        let row = PlanningState.Element(Fixtures.entry(17, "牛乳を買う、Memo", role: "StaticText")).showing(texts)
        #expect(row.showsText == ["title"])
    }

    @Test("leaves other elements, and a masked password field, unmarked", arguments: ["メモを作成", "••••••••"])
    func leavesOthers(label: String) {
        #expect(PlanningState.Element(Fixtures.entry(3, label, role: "TextField")).showing(texts).showsText == nil)
    }
}

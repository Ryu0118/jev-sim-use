import Foundation
import Jev
@testable import JevSimUseKit
import Testing

/// DONE is one option of the operation question, so its probability is shared with the operation that would finish
/// the goal: right after typing a query, Jev answered done 0.58 and press_return 0.33 while its own `finishes` said the
/// next operation would complete the goal, and the run exited 0 without pressing Return. The `satisfied` question asks
/// only whether the goal is already met. These are the ways combining the two answers can go wrong, written before the
/// code.
@Suite("DONE rests on whether the goal is already satisfied, not on how close the step is to finishing it")
struct DoneJudgementTests {
    /// A search screen after typing: a field to submit and a button to close it.
    private static let snapshot = Fixtures.snapshot(entries: [
        Fixtures.entry(10, "Query", role: "TextField"), Fixtures.entry(12, "close"),
    ])

    private static let menu = ActionCatalog.menu(for: snapshot, texts: [InputText(name: "query", value: "q")])

    /// A response with the operation distribution `operations` (the first is the choice), and `satisfied` when given.
    private static func response(_ operations: KeyValuePairs<String, Double>, satisfied: Double?) throws -> JevResponse {
        let probabilities = operations.map { #""\#($0.key)":\#($0.value)"# }.joined(separator: ",")
        let first = try #require(operations.first)
        let satisfiedAnswer = satisfied.map { #""satisfied":{"type":"noul","noul":\#($0)},"# } ?? ""
        let body = #"{"model":"m","answers":{"finishes":{"type":"noul","noul":0.6},"# + satisfiedAnswer
            + #""operation":{"type":"choice","choice":"\#(first.key)","probabilities":{\#(probabilities)},"confidence":\#(first.value)},"#
            + #""element_target":{"type":"choice","choice":"e12","probabilities":{"e12":0.9},"confidence":0.9}},"#
            + #""usage":{"input_tokens":1,"output_tokens":1}}"#
        return try JSONDecoder().decode(JevResponse.self, from: Data(body.utf8))
    }

    @Test("a DONE the goal is not yet satisfied for becomes the operation that finishes it, weighed by both answers")
    func doneBeforeSubmit() throws {
        let plan = try JevStepPlanner.interpret(
            Self.response(["done": 0.58, "press_return": 0.33, "blocked": 0.06, "tap": 0.03], satisfied: 0.29),
            menu: Self.menu,
        )
        #expect(plan.action == .device(.pressReturn))
        // DONE's 0.58 keeps the satisfied share (0.29); the unmet share (0.71) goes to the others by their weight.
        #expect(abs(plan.support - (0.33 + 0.58 * 0.71 * 0.33 / 0.42)) < 0.0001)
    }

    @Test("DONE's share on an unmet goal also backs the finishing operation Jev already chose")
    func doneShareBacksChosenAction() throws {
        let plan = try JevStepPlanner.interpret(
            Self.response(["press_return": 0.46, "done": 0.40, "blocked": 0.12, "tap": 0.02], satisfied: 0.2),
            menu: Self.menu,
        )
        #expect(plan.action == .device(.pressReturn))
        #expect(abs(plan.support - (0.46 + 0.40 * 0.8 * 0.46 / 0.6)) < 0.0001)
    }

    @Test("an operation DONE was not competing with keeps its probability on an unmet goal")
    func noDoneShareNoChange() throws {
        let plan = try JevStepPlanner.interpret(
            Self.response(["press_return": 0.6, "blocked": 0.4], satisfied: 0.1), menu: Self.menu,
        )
        #expect(abs(plan.support - 0.6) < 0.0001)
    }

    @Test("all of Jev's probability on DONE for an unmet goal hands over instead of acting on nothing")
    func contradictoryDone() throws {
        let plan = try JevStepPlanner.interpret(Self.response(["done": 1.0], satisfied: 0.2), menu: Self.menu)
        #expect(plan.action == .noneApplies)
    }

    @Test("a DONE on a satisfied goal rests on the satisfied answer, so a split operation answer does not lose it")
    func trueDoneKept() throws {
        let plan = try JevStepPlanner.interpret(
            Self.response(["done": 0.53, "blocked": 0.35, "tap": 0.1, "press_return": 0.02], satisfied: 0.74),
            menu: Self.menu,
        )
        #expect(plan.action == .done)
        #expect(abs(plan.support - 0.74) < 0.0001)
        #expect(plan.factors.map(\.name) == ["satisfied"])
    }

    @Test("an unsure satisfied answer keeps DONE, which then faces the DONE bar on it")
    func unsureSatisfied() throws {
        let plan = try JevStepPlanner.interpret(
            Self.response(["done": 0.9, "blocked": 0.1], satisfied: 0.5), menu: Self.menu,
        )
        #expect(plan.action == .done)
        #expect(plan.support < ActionPolicy.doneMinimum)
    }

    @Test("an action Jev chose is left as it was, whatever the satisfied answer says")
    func actionUntouched() throws {
        let plan = try JevStepPlanner.interpret(
            Self.response(["press_return": 0.63, "done": 0.29, "blocked": 0.08], satisfied: 0.9), menu: Self.menu,
        )
        #expect(plan.action == .device(.pressReturn))
        #expect(abs(plan.support - 0.63) < 0.0001)
    }

    @Test("without a satisfied answer, DONE rests on the operation answer as before")
    func missingSatisfied() throws {
        let plan = try JevStepPlanner.interpret(Self.response(["done": 0.7, "blocked": 0.3], satisfied: nil), menu: Self.menu)
        #expect(plan.action == .done)
        #expect(abs(plan.support - 0.7) < 0.0001)
    }

    @Test("asks whether the goal is already satisfied in the same request, on every step")
    func asked() throws {
        let data = try JSONEncoder().encode(JevStepPlanner.questions(for: Self.menu))
        let questions = try #require(JSONSerialization.jsonObject(with: data) as? [String: [String: Any]])
        #expect(questions["satisfied"]?["type"] as? String == "noul")
    }
}

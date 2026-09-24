import Foundation
import Jev
@testable import JevSimUseKit
import Testing

struct JevStepPlannerTests {
    private let snapshot = Fixtures.snapshot(entries: [Fixtures.entry(4, "Wi-Fi"), Fixtures.entry(5, "Wi-Fi")])

    private func request(texts: [InputText] = []) -> PlanRequest {
        PlanRequest(
            goal: "Open Wi-Fi settings", snapshot: snapshot, menu: ActionCatalog.menu(for: snapshot, texts: texts), history: [],
        )
    }

    @Test("composes the operation with its target and takes the weaker of the two as support")
    func composesTap() async throws {
        let transport = StubTransport(body: StubTransport.answer(
            operation: "tap", confidence: 0.9, finishes: 0.8, extra: [("element_target", "e4", 0.6)],
        ))
        let plan = try await transport.planner().plan(request())
        #expect(plan.action == .tap(alias: 4, role: "Button", label: "Wi-Fi"))
        #expect(plan.support == 0.6)
        #expect(plan.finishes.value == 0.8)
        let body = try #require(transport.lastRequestBody)
        #expect(body.contains(#""e4":null"#) && body.contains(#""id":"e4""#))
        #expect(body.contains(#""goal":"Open Wi-Fi settings""#))
    }

    @Test("reads DONE and BLOCKED from the operation answer alone")
    func stops() async throws {
        let done = try await StubTransport(body: StubTransport.answer(operation: "done", confidence: 0.7)).planner().plan(request())
        #expect(done.action == .done && done.support == 0.7)
        let blocked = try await StubTransport(body: StubTransport.answer(operation: "blocked")).planner().plan(request())
        #expect(blocked.action == .noneApplies)
    }

    @Test("rejects a target that was not offered")
    func unknownTarget() async {
        let transport = StubTransport(body: StubTransport.answer(operation: "tap", extra: [("element_target", "e99", 0.9)]))
        await #expect(throws: PlanningError.unknownChoice("e99")) { try await transport.planner().plan(request()) }
    }

    @Test("explains a 422 as a possibly oversized screen")
    func rejected() async {
        let transport = StubTransport(status: 422, body: "too long")
        await #expect(throws: PlanningError.rejected(body: "too long")) { try await transport.planner().plan(request()) }
    }

    @Test("adds up target probability split between elements with the same role and label")
    func pooledTarget() throws {
        let body = #"{"model":"m","answers":{"element_target":{"type":"choice","choice":"e4","probabilities":{"e4":0.45,"e5":0.4},"confidence":0.45}},"usage":{"input_tokens":1,"output_tokens":1}}"#
        let response = try JSONDecoder().decode(JevResponse.self, from: Data(body.utf8))
        let (_, support) = try JevStepPlanner.target("element_target", among: request().menu.elements, in: response)
        #expect(abs(support - 0.85) < 0.0001)
    }

    @Test("every question carries the shared rules, since target questions cannot see the operation answer")
    func sharedRules() throws {
        let data = try JSONEncoder().encode(JevStepPlanner.questions(for: request(texts: []).menu))
        let questions = try #require(JSONSerialization.jsonObject(with: data) as? [String: [String: Any]])
        #expect(Set(questions.keys) == ["operation", "element_target", "finishes"])
        for (name, question) in questions {
            let instructions = try #require(question["instructions"] as? String)
            #expect(instructions.contains("`notes`") && instructions.contains("no visible effect"), "\(name) lacks the rules")
        }
    }
}

@Suite("Supervisor notes reach Jev, and long sessions are trimmed to fit the state limit")
struct PlanningStateNotesTests {
    @Test("sends notes, the effect of each step, and only the most recent history and notes")
    func trimsSession() throws {
        let snapshot = Fixtures.snapshot(entries: [Fixtures.entry(4, "Wi-Fi")])
        let request = PlanRequest(
            goal: "g", snapshot: snapshot, menu: ActionCatalog.menu(for: snapshot, texts: []),
            history: (1 ... 30).map { HistoryEntry(step: $0, action: "a", screenChanged: false) },
            notes: (1 ... 12).map { "note \($0)" },
        )
        let state = PlanningState(request)
        #expect(state.history.map(\.step) == Array(11 ... 30))
        #expect(state.notes.first == "note 3")
        let json = try String(decoding: JSONEncoder().encode(state), as: UTF8.self)
        #expect(json.contains(#""notes":["note 3""#))
        #expect(json.contains(#""result":"no visible effect""#))
    }
}

@Suite("Named texts reach Jev by name only, never by value")
struct JevStepPlannerTextTests {
    @Test("types into the chosen field with the chosen text, and keeps the value out of the request")
    func valueStaysLocal() async throws {
        let snapshot = Fixtures.snapshot(entries: [Fixtures.entry(4, "Password", role: "SecureTextField")])
        let menu = ActionCatalog.menu(for: snapshot, texts: [InputText(name: "password", value: "hunter2")])
        let transport = StubTransport(body: StubTransport.answer(
            operation: "enter_text", extra: [("field_target", "e4", 0.9), ("text_to_enter", "password", 0.95)],
        ))
        let plan = try await transport.planner().plan(PlanRequest(goal: "Log in", snapshot: snapshot, menu: menu, history: []))
        #expect(plan.action == .enterText(field: 4, label: "Password", text: InputText(name: "password", value: "hunter2")))
        #expect(plan.action.description == "Enter the password into \"Password\"")
        let body = try #require(transport.lastRequestBody)
        #expect(!body.contains("hunter2"))
    }
}

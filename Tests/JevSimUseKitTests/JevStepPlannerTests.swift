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

    @Test("sends the request again when the connection drops, and gives up after three attempts")
    func retriesTransport() async throws {
        let answer = StubTransport.answer(operation: "done")
        func planner(_ transport: FlakyTransport) -> JevStepPlanner {
            JevStepPlanner(client: JevClient(
                apiKey: "k", endpoint: URL(string: "http://localhost/jev")!, transport: transport, retryPolicy: .none,
            ))
        }
        #expect(try await planner(FlakyTransport(failures: 2, body: answer)).plan(request()).action == .done)
        await #expect(throws: JevError.self) { try await planner(FlakyTransport(failures: 3, body: answer)).plan(request()) }
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

    @Test("adds up the two rotation directions, which both reach any heading")
    func pooledRotation() throws {
        let snapshot = Fixtures.snapshot(entries: [Fixtures.entry(2, "マップ", role: "Image")])
        let menu = ActionCatalog.menu(for: snapshot, texts: [])
        let body = #"{"model":"m","answers":{"finishes":{"type":"noul","noul":0.2},"operation":{"type":"choice","choice":"rotate_clockwise","probabilities":{"rotate_clockwise":0.4,"rotate_counterclockwise":0.35,"scroll_to_reveal_below":0.25},"confidence":0.4},"element_target":{"type":"choice","choice":"e2","probabilities":{"e2":0.95},"confidence":0.95}},"usage":{"input_tokens":1,"output_tokens":1}}"#
        let plan = try JevStepPlanner.interpret(JSONDecoder().decode(JevResponse.self, from: Data(body.utf8)), menu: menu)
        #expect(plan.action == .gesture(.rotateClockwise, alias: 2, role: "Image", label: "マップ"))
        #expect(abs(plan.support - 0.75) < 0.0001)
    }

    @Test("two rotation directions together beat a scroll that is individually more probable")
    func groupArgmax() throws {
        let body = #"{"model":"m","answers":{"operation":{"type":"choice","choice":"scroll_to_reveal_above","probabilities":{"scroll_to_reveal_above":0.3,"rotate_clockwise":0.25,"rotate_counterclockwise":0.2},"confidence":0.3}},"usage":{"input_tokens":1,"output_tokens":1}}"#
        let answer = try #require({ () -> Answer.Choice? in
            if case let .choice(choice) = try JSONDecoder().decode(JevResponse.self, from: Data(body.utf8)).answers["operation"] {
                return choice
            }
            return nil
        }())
        let (operation, support) = JevStepPlanner.pooledOperation(answer.probabilities, among: [
            .device(.revealContentAbove), .gesture(.rotateClockwise), .gesture(.rotateCounterclockwise),
        ])
        #expect(operation == .gesture(.rotateClockwise))
        #expect(abs(support - 0.45) < 0.0001)
    }

    @Test("tapping the field Jev would type into adds up with typing into it")
    func tapThenType() throws {
        let snapshot = Fixtures.snapshot(entries: [Fixtures.entry(13, "タイトル", role: "TextField")])
        let menu = ActionCatalog.menu(for: snapshot, texts: [InputText(name: "title", value: "牛乳を買う")])
        let body = StubTransport.answer(
            operation: "enter_text", confidence: 0.59,
            extra: [("element_target", "e13", 0.77), ("field_target", "e13", 1), ("text_to_enter", "title", 1)],
        ).replacingOccurrences(of: #""enter_text":0.59}"#, with: #""enter_text":0.59,"tap":0.28}"#)
        let plan = try JevStepPlanner.interpret(JSONDecoder().decode(JevResponse.self, from: Data(body.utf8)), menu: menu)
        #expect(plan.action == .enterText(field: 13, label: "タイトル", text: InputText(name: "title", value: "牛乳を買う")))
        #expect(abs(plan.support - 0.87) < 0.0001)
    }

    @Test("gates a reversible element action on the element, since how to touch it splits between gestures")
    func elementGesturesPool() throws {
        let snapshot = Fixtures.snapshot(entries: [Fixtures.entry(17, "牛乳を買う", role: "StaticText")])
        let menu = ActionCatalog.menu(for: snapshot, texts: [])
        let body = #"{"model":"m","answers":{"finishes":{"type":"noul","noul":0.4},"operation":{"type":"choice","choice":"tap","probabilities":{"tap":0.46,"long_press":0.28,"swipe_left":0.22,"blocked":0.04},"confidence":0.3},"element_target":{"type":"choice","choice":"e17","probabilities":{"e17":0.65},"confidence":0.6}},"usage":{"input_tokens":1,"output_tokens":1}}"#
        let plan = try JevStepPlanner.interpret(JSONDecoder().decode(JevResponse.self, from: Data(body.utf8)), menu: menu)
        #expect(plan.action == .tap(alias: 17, role: "StaticText", label: "牛乳を買う"))
        #expect(abs(plan.support - 0.65) < 0.0001)
    }

    @Test("adds up targets that all hold the item the goal names, since any of them meets the goal")
    func goalTermTargetsPool() throws {
        let snapshot = Fixtures.snapshot(entries: [
            Fixtures.entry(7, "暗いレッドピンク 13", role: "GenericElement"),
            Fixtures.entry(9, "レッドピンク 39", role: "GenericElement"),
            Fixtures.entry(8, "イエロー 49", role: "GenericElement"),
        ])
        let menu = ActionCatalog.menu(for: snapshot, texts: [])
        let body = #"{"model":"m","answers":{"finishes":{"type":"noul","noul":0.2},"operation":{"type":"choice","choice":"tap","probabilities":{"tap":0.97},"confidence":0.95},"element_target":{"type":"choice","choice":"e7","probabilities":{"e7":0.5,"e9":0.3,"e8":0.2},"confidence":0.3}},"usage":{"input_tokens":1,"output_tokens":1}}"#
        let response = try JSONDecoder().decode(JevResponse.self, from: Data(body.utf8))
        let plan = try JevStepPlanner.interpret(response, menu: menu, goal: "Set the ルートの色 to a レッドピンク color")
        #expect(plan.action == .tap(alias: 7, role: "GenericElement", label: "暗いレッドピンク 13"))
        #expect(abs(plan.support - 0.8) < 0.0001)
        #expect(try abs(JevStepPlanner.interpret(response, menu: menu).support - 0.5) < 0.0001)
    }

    @Test("keeps a destructive tap's own probability, so a split does not carry it over the irreversible bar")
    func destructiveTapDoesNotPool() throws {
        let snapshot = Fixtures.snapshot(entries: [Fixtures.entry(19, "削除")])
        let menu = ActionCatalog.menu(for: snapshot, texts: [])
        let body = #"{"model":"m","answers":{"finishes":{"type":"noul","noul":0.4},"operation":{"type":"choice","choice":"tap","probabilities":{"tap":0.46,"long_press":0.28,"swipe_left":0.22},"confidence":0.3},"element_target":{"type":"choice","choice":"e19","probabilities":{"e19":0.95},"confidence":0.9}},"usage":{"input_tokens":1,"output_tokens":1}}"#
        let plan = try JevStepPlanner.interpret(JSONDecoder().decode(JevResponse.self, from: Data(body.utf8)), menu: menu)
        #expect(abs(plan.support - 0.46) < 0.0001)
    }

    @Test("a typing step logs each answer its support depends on, so the lowest one is visible")
    func supportBreakdown() throws {
        let snapshot = Fixtures.snapshot(entries: [Fixtures.entry(10, "パスワード", role: "TextField")])
        let menu = ActionCatalog.menu(for: snapshot, texts: [InputText(name: "password", value: "x")])
        let body = StubTransport.answer(
            operation: "enter_text", confidence: 0.97,
            extra: [("field_target", "e10", 0.65), ("text_to_enter", "password", 0.9)],
        )
        let plan = try JevStepPlanner.interpret(JSONDecoder().decode(JevResponse.self, from: Data(body.utf8)), menu: menu)
        #expect(plan.factors.map(\.name) == ["operation", "field", "text"])
        #expect(abs(plan.support - 0.65) < 0.0001)
        #expect(AgentEvent.planned(step: 1, plan: plan).description.contains("[operation 0.97, field 0.65, text 0.90]"))
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

@Suite("The state names the current screen and where back leads, so Jev can tell a sub-screen from the top")
struct PlanningStateNavigationTests {
    @Test("sends the navigation title and the back button's label")
    func titleAndBack() throws {
        let title = Fixtures.entry(7, "一般", role: "Heading", band: "Top")
        let back = UIEntry(
            aliases: ElementAliases(alias: 6), role: "Button", label: "設定", states: [], value: nil,
            uniqueId: "BackButton", region: nil, frame: nil,
        )
        let json = try String(decoding: JSONEncoder().encode(PlanningState.Screen(Fixtures.snapshot(entries: [back, title]))), as: UTF8.self)
        #expect(json.contains(#""title":"一般""#) && json.contains(#""back":"設定""#))
    }
}

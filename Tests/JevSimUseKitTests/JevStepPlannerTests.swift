import Foundation
import Jev
@testable import JevSimUseKit
import Testing

struct JevStepPlannerTests {
    private let request = PlanRequest(
        goal: "Open Wi-Fi settings",
        snapshot: Fixtures.snapshot(entries: [Fixtures.entry(4, "Wi-Fi")]),
        actions: ActionCatalog.actions(for: Fixtures.snapshot(entries: [Fixtures.entry(4, "Wi-Fi")]), texts: []),
        history: [],
    )

    @Test("maps the chosen option back to the offered action")
    func plan() async throws {
        let transport = StubTransport(body: StubTransport.answer(choice: "e4"))
        let plan = try await transport.planner().plan(request)
        #expect(plan.action == .tap(alias: 4, role: "Button", label: "Wi-Fi"))
        #expect(plan.confidence == 0.9)
        #expect(plan.goalReached.value == 0.1)
        let body = try #require(transport.lastRequestBody)
        #expect(body.contains(#""e4":null"#))
        #expect(body.contains(#""id":"e4""#))
        #expect(body.contains(#""label":"Wi-Fi""#))
        #expect(!body.contains("Tap the Button labelled"))
        #expect(body.contains(#""goal":"Open Wi-Fi settings""#))
    }

    @Test("rejects a choice that was not offered")
    func unknownChoice() async {
        let transport = StubTransport(body: StubTransport.answer(choice: "e99"))
        await #expect(throws: PlanningError.unknownChoice("e99")) { try await transport.planner().plan(request) }
    }

    @Test("explains a 422 as a possibly oversized screen")
    func rejected() async {
        let transport = StubTransport(status: 422, body: "too long")
        await #expect(throws: PlanningError.rejected(body: "too long")) { try await transport.planner().plan(request) }
    }

    @Test("adds up probability split between options that do the same thing")
    func equivalentProbability() {
        let actions: [AgentAction] = [
            .tap(alias: 1, role: "Button", label: "Calendar"),
            .tap(alias: 2, role: "Button", label: "Calendar"),
            .device(.goBack),
        ]
        let support = JevStepPlanner.equivalentProbability(
            of: actions[0], among: actions, ["e1": 0.45, "e2": 0.4, "go_back": 0.15],
        )
        #expect(abs(support - 0.85) < 0.0001)
    }
}

struct PlanningStateTests {
    @Test("presents toggle values as on and off", arguments: [("1", "on"), ("0", "off"), ("2", "2")])
    func toggleValues(raw: String, expected: String) {
        let entry = UIEntry(
            aliases: ElementAliases(alias: 9), role: "CheckBox", label: "Dark", states: [], value: raw,
            uniqueId: nil, region: nil, frame: nil,
        )
        #expect(PlanningState.Element.readableValue(entry) == expected)
    }
}

@Suite("Supervisor notes reach Jev, and long sessions are trimmed to fit the state limit")
struct PlanningStateNotesTests {
    @Test("sends notes and only the most recent history and notes")
    func trimsSession() throws {
        let snapshot = Fixtures.snapshot(entries: [Fixtures.entry(4, "Wi-Fi")])
        let request = PlanRequest(
            goal: "g", snapshot: snapshot, actions: [],
            history: (1 ... 30).map { HistoryEntry(step: $0, action: "a") },
            notes: (1 ... 12).map { "note \($0)" },
        )
        let state = PlanningState(request)
        #expect(state.history.map(\.step) == Array(11 ... 30))
        #expect(state.notes.first == "note 3")
        let json = try String(decoding: JSONEncoder().encode(state), as: UTF8.self)
        #expect(json.contains(#""notes":["note 3""#))
    }

    @Test("both questions tell Jev to use the notes")
    func questionsMentionNotes() throws {
        let body = try String(decoding: JSONEncoder().encode(JevStepPlanner.questions(for: [.noneApplies])), as: UTF8.self)
        #expect(body.components(separatedBy: "`notes`").count == 3)
    }
}

@Suite("Gestures other than taps are chosen through two speculative questions in the same request")
struct JevStepPlannerGestureTests {
    private let targets = [GestureTarget(alias: 3, role: "Image", label: "Map")]

    private func request() -> PlanRequest {
        let snapshot = Fixtures.snapshot(entries: [Fixtures.entry(3, "Map", role: "Image")])
        return PlanRequest(goal: "Zoom in on the map", snapshot: snapshot, actions: [.noneApplies], history: [], gestureTargets: targets)
    }

    @Test("composes the gate, the gesture, and the element into one action, with the weakest confidence as support")
    func composes() async throws {
        let transport = StubTransport(body: StubTransport.answer(
            choice: "gesture_on_element",
            extra: [("element_gesture", "pinch_out", 0.8), ("gesture_target", "e3", 0.95)],
        ))
        let plan = try await transport.planner().plan(request())
        #expect(plan.action == .gesture(.pinchOut, alias: 3, role: "Image", label: "Map"))
        #expect(plan.support == 0.8)
        let body = try #require(transport.lastRequestBody)
        #expect(body.contains("element_gesture") && body.contains("gesture_target") && body.contains("gesture_on_element"))
    }

    @Test("asks no gesture questions when the screen has no targets")
    func noTargets() throws {
        let body = try String(decoding: JSONEncoder().encode(JevStepPlanner.questions(for: [.noneApplies])), as: UTF8.self)
        #expect(!body.contains("gesture"))
    }
}

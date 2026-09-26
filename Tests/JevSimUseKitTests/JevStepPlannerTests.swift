import Foundation
import Jev
@testable import JevSimUseKit
import Testing

/// How one Jev response becomes a step. Sending the request, reading DONE and BLOCKED, the goal and rules in the
/// state, typing by name only, and a 422 run end to end against a stub server in scripts/e2e.sh; these are the answers
/// a stub script would never send and the support arithmetic, one row per rule.
struct JevStepPlannerTests {
    /// A response body; each answer is a choice named by its question, with its options' probabilities.
    static func body(finishes: Double = 0.2, _ choices: [String: (choice: String, probabilities: [String: Double])]) -> String {
        let answers = choices.mapValues { answer -> [String: Any] in
            ["type": "choice", "choice": answer.choice, "probabilities": answer.probabilities,
             "confidence": answer.probabilities[answer.choice] ?? 0]
        }.merging(["finishes": ["type": "noul", "noul": finishes]]) { $1 }
        let json: [String: Any] = ["model": "m", "answers": answers, "usage": ["input_tokens": 1, "output_tokens": 1]]
        return String(decoding: (try? JSONSerialization.data(withJSONObject: json)) ?? Data(), as: UTF8.self)
    }

    private static let snapshot = Fixtures.snapshot(entries: [
        Fixtures.entry(4, "Wi-Fi"), Fixtures.entry(5, "Name", role: "TextField"),
    ])

    @Test("rejects an answer that names something the request did not offer", arguments: [
        ("an unknown operation", body(["operation": ("fly", ["fly": 0.9])]), PlanningError.unknownChoice("fly")),
        ("an unknown target", body(["operation": ("tap", ["tap": 0.9]), "element_target": ("e99", ["e99": 0.9])]),
         .unknownChoice("e99")),
        ("an unknown text name", body([
            "operation": ("enter_text", ["enter_text": 0.9]), "field_target": ("e5", ["e5": 0.9]),
            "text_to_enter": ("password", ["password": 0.9]),
        ]), .unknownChoice("password")),
        ("no target answer for a tap", body(["operation": ("tap", ["tap": 0.9])]), .missingChoice),
        ("no operation answer", body([:]), .missingChoice),
    ] as [(String, String, PlanningError)])
    func unoffered(_: String, response: String, expected: PlanningError) async {
        await #expect(throws: expected) { try await StubTransport(body: response).planner().plan(Self.request()) }
    }

    @Test("sends the request again when the connection drops, and gives up after three attempts")
    func retriesTransport() async throws {
        let answer = Self.body(["operation": ("done", ["done": 0.9])])
        func planner(_ transport: FlakyTransport) -> JevStepPlanner {
            JevStepPlanner(client: JevClient(
                apiKey: "k", endpoint: URL(string: "http://localhost/jev")!, transport: transport, retryPolicy: .none,
            ))
        }
        #expect(try await planner(FlakyTransport(failures: 2, body: answer)).plan(Self.request()).action == .done)
        await #expect(throws: JevError.self) { try await planner(FlakyTransport(failures: 3, body: answer)).plan(Self.request()) }
    }

    @Test("support is the weakest answer the action depends on, pooled where options do the same thing", arguments: [
        SupportCase(
            testDescription: "targets with the same role and label pool",
            entries: [Fixtures.entry(4, "Wi-Fi"), Fixtures.entry(5, "Wi-Fi")],
            response: body(["operation": ("tap", ["tap": 0.9]), "element_target": ("e4", ["e4": 0.45, "e5": 0.4])]),
            action: .tap(alias: 4, role: "Button", label: "Wi-Fi"), support: 0.85,
        ),
        SupportCase(
            testDescription: "the two rotation directions pool, and together beat a scroll that is more probable alone",
            entries: [Fixtures.entry(2, "Map", role: "Image")],
            response: body([
                "operation": ("scroll_to_reveal_below", ["scroll_to_reveal_below": 0.3, "rotate_clockwise": 0.25, "rotate_counterclockwise": 0.2]),
                "element_target": ("e2", ["e2": 0.95]),
            ]),
            action: .gesture(.rotateClockwise, alias: 2, role: "Image", label: "Map"), support: 0.45,
        ),
        SupportCase(
            testDescription: "tapping the field Jev would type into adds up with typing into it",
            entries: [Fixtures.entry(13, "Title", role: "TextField")], texts: [InputText(name: "title", value: "Buy milk")],
            response: body([
                "operation": ("enter_text", ["enter_text": 0.59, "tap": 0.28]), "element_target": ("e13", ["e13": 0.77]),
                "field_target": ("e13", ["e13": 1]), "text_to_enter": ("title", ["title": 1]),
            ]),
            action: .enterText(field: 13, label: "Title", text: InputText(name: "title", value: "Buy milk")), support: 0.87,
        ),
        SupportCase(
            testDescription: "a reversible element action is gated on the element, as how to touch it splits between gestures",
            entries: [Fixtures.entry(17, "Buy milk", role: "StaticText")],
            response: body([
                "operation": ("tap", ["tap": 0.46, "long_press": 0.28, "swipe_left": 0.22, "blocked": 0.04]),
                "element_target": ("e17", ["e17": 0.65]),
            ]),
            action: .tap(alias: 17, role: "StaticText", label: "Buy milk"), support: 0.65,
        ),
        SupportCase(
            testDescription: "a destructive tap keeps its own probability, so a split does not carry it over the bar",
            entries: [Fixtures.entry(19, "Delete")],
            response: body([
                "operation": ("tap", ["tap": 0.46, "long_press": 0.28, "swipe_left": 0.22]), "element_target": ("e19", ["e19": 0.95]),
            ]),
            action: .tap(alias: 19, role: "Button", label: "Delete"), support: 0.46,
        ),
        SupportCase(
            testDescription: "targets that all hold the item the goal quotes pool, since any of them meets the goal",
            entries: swatches, goal: "Set the route color to a Красный color", response: swatchResponse,
            action: .tap(alias: 7, role: "GenericElement", label: "Тёмно-Красный 13"), support: 0.8,
        ),
        SupportCase(
            testDescription: "without that goal the same targets do not pool",
            entries: swatches, response: swatchResponse,
            action: .tap(alias: 7, role: "GenericElement", label: "Тёмно-Красный 13"), support: 0.5,
        ),
    ])
    func support(_ rule: SupportCase) throws {
        let menu = ActionCatalog.menu(for: Fixtures.snapshot(entries: rule.entries), texts: rule.texts)
        let response = try JSONDecoder().decode(JevResponse.self, from: Data(rule.response.utf8))
        let plan = try JevStepPlanner.interpret(response, menu: menu, goal: rule.goal)
        #expect(plan.action == rule.action)
        #expect(abs(plan.support - rule.support) < 0.0001)
    }

    /// One support rule: the screen, the goal, the response, and the action and support it must give.
    struct SupportCase: Sendable, CustomTestStringConvertible {
        let testDescription: String
        let entries: [UIEntry]
        var texts: [InputText] = []
        var goal = ""
        let response: String
        let action: AgentAction
        let support: Double
    }

    @Test("sends notes and only the most recent history and notes, to stay within the state limit")
    func trimsSession() {
        let snapshot = Fixtures.snapshot(entries: [Fixtures.entry(4, "Wi-Fi")])
        let state = PlanningState(PlanRequest(
            goal: "g", snapshot: snapshot, menu: ActionCatalog.menu(for: snapshot, texts: []),
            history: (1 ... 30).map { HistoryEntry(step: $0, action: "a", screenChanged: false) },
            notes: (1 ... 12).map { "note \($0)" },
        ))
        #expect(state.history.map(\.step) == Array(11 ... 30))
        #expect(state.notes == (3 ... 12).map { "note \($0)" })
    }

    private static let swatches = [
        Fixtures.entry(7, "Тёмно-Красный 13", role: "GenericElement"),
        Fixtures.entry(9, "Красный 39", role: "GenericElement"),
        Fixtures.entry(8, "Жёлтый 49", role: "GenericElement"),
    ]

    private static let swatchResponse = body([
        "operation": ("tap", ["tap": 0.97]), "element_target": ("e7", ["e7": 0.5, "e9": 0.3, "e8": 0.2]),
    ])

    private static func request() -> PlanRequest {
        PlanRequest(
            goal: "g", snapshot: snapshot,
            menu: ActionCatalog.menu(for: snapshot, texts: [InputText(name: "name", value: "x")]), history: [],
        )
    }
}

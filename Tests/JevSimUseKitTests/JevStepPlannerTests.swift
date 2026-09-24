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

    private func planner(_ transport: StubTransport) -> JevStepPlanner {
        let endpoint = URL(string: "http://localhost/jev")!
        let client = JevClient(apiKey: "k", endpoint: endpoint, transport: transport, retryPolicy: .none)
        return JevStepPlanner(client: client)
    }

    @Test("maps the chosen option back to the offered action")
    func plan() async throws {
        let transport = StubTransport(body: StubTransport.answer(choice: "tap_4"))
        let plan = try await planner(transport).plan(request)
        #expect(plan.action == .tap(alias: 4, role: "Button", label: "Wi-Fi"))
        #expect(plan.confidence == 0.9)
        #expect(plan.goalReached.value == 0.1)
        let body = try #require(transport.lastRequestBody)
        #expect(body.contains(#""tap_4":"Tap the Button labelled \"Wi-Fi\"""#))
        #expect(body.contains(#""goal":"Open Wi-Fi settings""#))
    }

    @Test("rejects a choice that was not offered")
    func unknownChoice() async {
        let transport = StubTransport(body: StubTransport.answer(choice: "tap_99"))
        await #expect(throws: PlanningError.unknownChoice("tap_99")) { try await planner(transport).plan(request) }
    }

    @Test("explains a 422 as a possibly oversized screen")
    func rejected() async {
        let transport = StubTransport(status: 422, body: "too long")
        await #expect(throws: PlanningError.rejected(body: "too long")) { try await planner(transport).plan(request) }
    }
}

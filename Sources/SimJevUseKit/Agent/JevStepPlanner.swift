import Jev

/// Plans a step by asking Jev two questions in one request: is the goal reached,
/// and which of this screen's actions comes next.
public struct JevStepPlanner: StepPlanning {
    static let goalQuestion = "goal_reached"
    static let actionQuestion = "next_action"

    private let client: JevClient

    /// Creates a planner that sends every step to `client`.
    public init(client: JevClient) {
        self.client = client
    }

    /// Asks Jev about `request` in a single evaluation.
    public func plan(_ request: PlanRequest) async throws -> StepPlan {
        let questions = try Self.questions(for: request.actions)
        let response: JevResponse
        do {
            response = try await client.evaluate(state: PlanningState(request), questions: questions)
        } catch let JevError.invalidRequest(body) {
            throw PlanningError.rejected(body: body)
        }
        return try Self.interpret(response, actions: request.actions)
    }

    static func questions(for actions: [AgentAction]) throws -> JevQuestionSet {
        let goal = try Question(
            instructions: "Does the current screen show that the goal has been fully achieved?",
            kind: .noul(
                whenTrue: "The screen shows the end state the goal describes; no further action is needed.",
                whenFalse: "The goal needs at least one more action, or the screen shows an unrelated state.",
            ),
        )
        let next = try Question(
            instructions: """
            Which single action best advances the goal from the current screen? \
            Avoid repeating previous actions that did not change the screen.
            """,
            kind: .choice(actions.map { ChoiceOption($0.optionName, $0.optionDescription) }),
        )
        return try JevQuestionSet([goalQuestion: goal, actionQuestion: next])
    }
}

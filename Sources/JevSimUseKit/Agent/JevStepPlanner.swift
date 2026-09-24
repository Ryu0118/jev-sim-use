import Jev

/// Plans a step by asking Jev two questions in one request: is the goal reached,
/// and which of this screen's actions comes next.
package struct JevStepPlanner: StepPlanning {
    static let goalQuestion = "goal_reached"
    static let actionQuestion = "next_action"

    private let client: JevClient

    /// Creates a planner that sends every step to `client`.
    package init(client: JevClient) {
        self.client = client
    }

    /// Asks Jev about `request` in a single evaluation.
    package func plan(_ request: PlanRequest) async throws -> StepPlan {
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
            instructions: "Does `screen` show that `goal` has been fully achieved?",
            kind: .noul(
                whenTrue: "`screen` shows the end state `goal` describes; no further action is needed.",
                whenFalse: "`goal` needs at least one more action, or `screen` shows an unrelated state.",
            ),
        )
        let next = try Question(
            instructions: """
            Which single option best advances `goal` from `screen`? An option named like `e12` taps the element \
            with that id in `screen.elements`; the other options are described. `history` lists the steps taken so far.
            """,
            kind: .choice(actions.map { ChoiceOption($0.optionName, $0.optionCriteria) }),
        )
        return try JevQuestionSet([goalQuestion: goal, actionQuestion: next])
    }
}

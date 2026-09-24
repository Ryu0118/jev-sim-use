import Jev

/// Plans a step in one request: is the goal reached, and which of this screen's actions comes next. When the screen
/// has gesture targets, two speculative questions ride along (which gesture, on which element); code reads them only
/// when `next_action` picks the gesture option.
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
        let questions = try Self.questions(for: request.actions, gestureTargets: request.gestureTargets)
        let response: JevResponse
        do {
            response = try await client.evaluate(state: PlanningState(request), questions: questions)
        } catch let JevError.invalidRequest(body) {
            throw PlanningError.rejected(body: body)
        }
        return try Self.interpret(response, actions: request.actions, gestureTargets: request.gestureTargets)
    }

    static func questions(for actions: [AgentAction], gestureTargets: [GestureTarget] = []) throws -> JevQuestionSet {
        let goal = try Question(
            instructions: """
            Does `screen` show that `goal` has been fully achieved? `notes` lists facts a supervisor verified about \
            this app; when one says what the finished state looks like, judge by it.
            """,
            kind: .noul(
                whenTrue: "`screen` shows the end state `goal` describes; no further action is needed.",
                whenFalse: "`goal` needs at least one more action, or `screen` shows an unrelated state.",
            ),
        )
        let next = try Question(
            instructions: """
            Which single option best advances `goal` from `screen`? An option named like `e12` taps the element \
            with that id in `screen.elements`; the other options are described. `history` lists the steps taken so far. \
            `notes` lists facts a supervisor verified about this app, such as where a setting lives; follow them.
            """,
            kind: .choice(
                actions.map { ChoiceOption($0.optionName, $0.optionCriteria) }
                    + (gestureTargets.isEmpty ? [] : [ChoiceOption(gestureOption, gestureOptionCriteria)]),
            ),
        )
        let questions = [goalQuestion: goal, actionQuestion: next]
        return try JevQuestionSet(gestureTargets.isEmpty ? questions : questions.merging(gestureQuestions(gestureTargets)) { $1 })
    }
}

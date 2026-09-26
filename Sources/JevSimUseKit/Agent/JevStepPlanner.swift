import Jev

/// Plans a step in one request, jev-ultrafast style: which operation to run, which target each kind of operation
/// would use, and whether the chosen operation would finish the goal. Code reads only the target answer that matches
/// the chosen operation; the others are speculative and cost no extra round trip.
package struct JevStepPlanner: StepPlanning {
    static let operationQuestion = "operation"
    static let elementQuestion = "element_target"
    static let fieldQuestion = "field_target"
    static let textQuestion = "text_to_enter"
    static let finishesQuestion = "finishes"
    static let irreversibleQuestion = "irreversible"
    static let satisfiedQuestion = "satisfied"

    /// Opens every question. The rules, built by `PlanningRules` from the step's offered operations, travel once as the
    /// state's `rules`: target questions cannot see the operation answer, and swift-jev's request has no shared
    /// instructions field, so repeating them in each question sent them three to five times per request. `rules` is
    /// guidance, unlike the screen text it warns about.
    static let rulesPointer = "Follow `rules`, which say how to decide; `screen` is the data to judge."

    /// How many times a request is sent when the connection fails.
    static let transportAttempts = 3

    private let client: JevClient

    /// Creates a planner that sends every step to `client`.
    package init(client: JevClient) {
        self.client = client
    }

    /// Asks Jev about `request` in a single evaluation.
    package func plan(_ request: PlanRequest) async throws -> StepPlan {
        let questions = try Self.questions(for: request.menu)
        let state = PlanningState(request)
        var attempt = 1
        while true {
            do {
                let response = try await client.evaluate(state: state, questions: questions)
                return try Self.interpret(response, menu: request.menu, goal: request.goal)
            } catch let JevError.invalidRequest(body) {
                throw PlanningError.rejected(body: body)
            } catch JevError.transport where attempt < Self.transportAttempts {
                // swift-jev retries only HTTP statuses; a dropped connection (NSURLError -1005 mid-run) ended the
                // run. An evaluation changes nothing, so sending it again is safe.
                attempt += 1
                try await Task.sleep(for: .milliseconds(300))
            }
        }
    }

    /// Every question opens with `rulesPointer`; the rules themselves travel once in the state.
    static func questions(for menu: ActionMenu) throws -> JevQuestionSet {
        var questions = try [
            operationQuestion: Question(
                instructions: "\(rulesPointer) Which operation should run now?",
                kind: .choice(menu.operations.map { ChoiceOption($0.optionName, $0.optionDescription) }),
            ),
            finishesQuestion: Question(
                instructions: """
                \(rulesPointer) Suppose the single best operation for this step runs now and works. Will every \
                part of `goal` then be satisfied?
                """,
                kind: .noul(
                    whenTrue: "That one operation completes what `goal` still needs; nothing else is required after it.",
                    whenFalse: "More operations are needed after it, or `goal` is already satisfied without it.",
                ),
            ),
            // DONE shares the operation question with the operation that would finish the goal, so its probability
            // says how close the step is, not whether the goal is met: after typing a query Jev chose done 0.58 over
            // press_return 0.33 and the run ended without Return. This asks only the latter, in the same request.
            satisfiedQuestion: Question(
                instructions: """
                \(rulesPointer) Is every part of `goal` already satisfied, so that no operation is still needed?
                """,
                kind: .noul(
                    whenTrue: "`screen`, with `history` for what earlier steps did, shows every part of `goal` done.",
                    whenFalse: "Some part of `goal` still needs an operation.",
                ),
            ),
        ]
        if !menu.elements.isEmpty {
            questions[elementQuestion] = try targetQuestion(
                "Suppose the operation acts on one element: a tap, press and hold, swipe, zoom, or rotation. "
                    + "Which element in `screen.elements` should it act on? Options are element ids.",
                menu.elements,
            )
        }
        // The "no" side names what an app can undo (closing, cancelling a clean edit, archiving, clearing a favorite):
        // described only as "toggles", those scored 0.39-0.65 and faced the irreversible bar; named, 0.12-0.31, while
        // deletes and discard confirmations stayed at 0.76-0.85.
        // Whether a tap can be undone is judged from what the control does, so a label in any language is read the
        // same way; like `finishes`, it is about the step's own choice and costs no extra round trip.
        if menu.operations.contains(.tap) {
            questions[irreversibleQuestion] = try Question(
                instructions: """
                \(rulesPointer) Suppose this step taps the element in `screen.elements` it would choose, whether or not \
                `goal` wants what that tap does. Would the tap lose data or state that going back cannot restore?
                """,
                kind: .noul(
                    whenTrue: "The tap deletes (even into a trash), erases, discards typed changes, sends, pays, or "
                        + "otherwise commits something going back does not undo.",
                    whenFalse: "The app can undo it: it opens, closes, dismisses, cancels or leaves an edit that has "
                        + "no typed changes, selects, navigates, archives, or sets or clears a mark or setting that can "
                        + "be set again, such as adding to or removing from favorites, a flag, or a toggle.",
                ),
            )
        }
        if menu.operations.contains(where: \.typesText) {
            questions[fieldQuestion] = try targetQuestion(
                "Suppose the operation types text. Which field in `screen.elements` should receive it? Do not "
                    + "choose a field that already holds the needed text. Options are element ids.",
                menu.fields,
            )
            questions[textQuestion] = try Question(
                instructions: "\(rulesPointer) Suppose the operation types text. Which of the named texts belongs there?",
                kind: .choice(menu.texts.map { ChoiceOption($0.name, "The text the user named \"\($0.name)\"") }),
            )
        }
        return try JevQuestionSet(questions)
    }

    private static func targetQuestion(_ instructions: String, _ targets: [ElementTarget]) throws -> Question {
        try Question(
            instructions: "\(rulesPointer) \(instructions) Another question decides the operation.",
            kind: .choice(targets.map { ChoiceOption($0.optionName, nil) }),
        )
    }
}

import Jev

extension JevStepPlanner {
    /// Composes the chosen operation with the answer to its target question. Choice options are built at runtime,
    /// so typed `ChoiceQuestion` reads do not apply: raw answers are matched against the options that were sent.
    ///
    /// Support is the weakest of the answers the action depends on, so a confident operation with an unsure target
    /// does not act.
    static func interpret(_ response: JevResponse, menu: ActionMenu) throws -> StepPlan {
        let operationAnswer = try choice(operationQuestion, in: response)
        guard let operation = menu.operations.first(where: { $0.optionName == operationAnswer.value }) else {
            throw PlanningError.unknownChoice(operationAnswer.value)
        }
        let (action, targetSupport) = try compose(operation, response: response, menu: menu)
        return try StepPlan(
            action: action,
            confidence: operationAnswer.confidence,
            support: min(operationAnswer.confidence, targetSupport),
            finishes: response.answers.noul(named: finishesQuestion),
            costUSD: response.usage.estimatedCostUSD,
            model: response.model,
        )
    }

    /// The chosen target and its support. Elements with the same role and label (two "Calendar" buttons) split the
    /// distribution without making the choice any less clear, so their probabilities add up.
    static func target(
        _ question: String,
        among targets: [ElementTarget],
        in response: JevResponse,
    ) throws -> (ElementTarget, Double) {
        let answer = try choice(question, in: response)
        guard let chosen = targets.first(where: { $0.optionName == answer.value }) else {
            throw PlanningError.unknownChoice(answer.value)
        }
        let alike = targets.filter { $0.role == chosen.role && $0.label == chosen.label && !chosen.label.isEmpty }
        let pooled = alike.reduce(0) { $0 + (answer.probabilities[$1.optionName] ?? 0) }
        return (chosen, max(answer.confidence, pooled))
    }

    private static func compose(
        _ operation: Operation,
        response: JevResponse,
        menu: ActionMenu,
    ) throws -> (AgentAction, Double) {
        switch operation {
        case .tap, .gesture:
            let (element, support) = try target(elementQuestion, among: menu.elements, in: response)
            let action: AgentAction = if case let .gesture(gesture) = operation {
                .gesture(gesture, alias: element.alias, role: element.role, label: element.label)
            } else {
                .tap(alias: element.alias, role: element.role, label: element.label)
            }
            return (action, support)
        case .enterText:
            let (field, fieldSupport) = try target(fieldQuestion, among: menu.fields, in: response)
            let textAnswer = try choice(textQuestion, in: response)
            guard let text = menu.texts.first(where: { $0.name == textAnswer.value }) else {
                throw PlanningError.unknownChoice(textAnswer.value)
            }
            return (.enterText(field: field.alias, label: field.label, text: text), min(fieldSupport, textAnswer.confidence))
        case let .device(action):
            return (.device(action), 1)
        case .done:
            return (.done, 1)
        case .blocked:
            return (.noneApplies, 1)
        }
    }

    private static func choice(_ question: String, in response: JevResponse) throws -> Answer.Choice {
        guard case let .choice(answer) = response.answers[question] else { throw PlanningError.missingChoice }
        return answer
    }
}

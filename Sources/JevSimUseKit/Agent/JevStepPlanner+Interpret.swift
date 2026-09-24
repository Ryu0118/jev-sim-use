import Jev

extension JevStepPlanner {
    /// Composes the chosen operation with the answer to its target question. Choice options are built at runtime,
    /// so typed `ChoiceQuestion` reads do not apply: raw answers are matched against the options that were sent.
    ///
    /// Support is the weakest of the answers the action depends on, so a confident operation with an unsure target
    /// does not act.
    static func interpret(_ response: JevResponse, menu: ActionMenu) throws -> StepPlan {
        let operationAnswer = try choice(operationQuestion, in: response)
        guard menu.operations.contains(where: { $0.optionName == operationAnswer.value }) else {
            throw PlanningError.unknownChoice(operationAnswer.value)
        }
        let probabilities = operationAnswer.probabilities
        var (operation, operationSupport) = pooledOperation(probabilities, among: menu.operations)
        // Tapping the field Jev would type into is only the first half of typing (enter_text taps it too): when the
        // tap target and the field target agree, the two operations are one intent and their probabilities add up.
        if [.tap, .enterText].contains(operation), menu.operations.contains(.enterText),
           let element = try? choice(elementQuestion, in: response).value,
           element == (try? choice(fieldQuestion, in: response).value)
        {
            operation = .enterText
            operationSupport = [Operation.tap, .enterText].reduce(0) { $0 + (probabilities[$1.optionName] ?? 0) }
        }
        let (action, targetSupport) = try compose(operation, response: response, menu: menu)
        let alternatives = probabilities
            .filter { $0.key != operation.optionName && $0.value >= 0.05 }
            .sorted { $0.value > $1.value }
            .prefix(2)
            .map { StepPlan.Alternative(name: $0.key, probability: $0.value) }
        return try StepPlan(
            action: action,
            confidence: probabilities[operation.optionName] ?? 0,
            support: min(operationSupport, targetSupport),
            finishes: response.answers.noul(named: finishesQuestion),
            alternatives: Array(alternatives),
            costUSD: response.usage.estimatedCostUSD,
            model: response.model,
        )
    }

    /// The operation to run: the most probable group of equivalent operations wins (two rotation directions can
    /// together outweigh a scroll that is individually more probable), and within it the more probable member.
    static func pooledOperation(_ probabilities: [String: Double], among operations: [Operation]) -> (Operation, Double) {
        func probability(_ operation: Operation) -> Double {
            probabilities[operation.optionName] ?? 0
        }
        let groups = operations.map { operation in
            (operation, operation.equivalents.reduce(0) { $0 + probability($1) })
        }
        guard let best = groups.max(by: { $0.1 < $1.1 }),
              let chosen = best.0.equivalents.max(by: { probability($0) < probability($1) })
        else { return (.blocked, 0) }
        return (chosen, best.1)
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

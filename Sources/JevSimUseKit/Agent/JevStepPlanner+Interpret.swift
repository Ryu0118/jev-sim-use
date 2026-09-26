import Jev

extension JevStepPlanner {
    /// Composes the chosen operation with the answer to its target question. Choice options are built at runtime,
    /// so typed `ChoiceQuestion` reads do not apply: raw answers are matched against the options that were sent.
    ///
    /// Support is the weakest of the answers the action depends on, so a confident operation with an unsure target
    /// does not act.
    static func interpret(_ response: JevResponse, menu: ActionMenu, goal: String = "") throws -> StepPlan {
        let operationAnswer = try choice(operationQuestion, in: response)
        guard menu.operations.contains(where: { $0.optionName == operationAnswer.value }) else {
            throw PlanningError.unknownChoice(operationAnswer.value)
        }
        // A missing answer or one of another type keeps DONE on the operation answer alone, as before the question.
        let satisfied = try? response.answers.noul(named: satisfiedQuestion)
        var probabilities = operationAnswer.probabilities
        if let satisfied, satisfied.value < 0.5 {
            probabilities = notDone(probabilities, satisfied: satisfied.value)
        }
        var (operation, operationSupport) = pooledOperation(probabilities, among: menu.operations)
        if operation == .done, let satisfied {
            return try StepPlan(
                action: .done, confidence: probabilities[Operation.done.optionName] ?? 0, support: satisfied.value,
                finishes: response.answers.noul(named: finishesQuestion),
                alternatives: alternatives(to: .done, in: probabilities),
                factors: [StepPlan.Factor(name: "satisfied", value: satisfied.value)],
                costUSD: response.usage.estimatedCostUSD, model: response.model,
            )
        }
        // Tapping the field Jev would type into is only the first half of typing (enter_text taps it too): when the
        // tap target and the field target agree, the two operations are one intent and their probabilities add up.
        // Appending and replacing stay apart: they leave different text behind.
        if operation == .tap || operation.typesText, menu.operations.contains(.enterText),
           let element = try? choice(elementQuestion, in: response).value,
           element == (try? choice(fieldQuestion, in: response).value)
        {
            let typing = operation.typesText ? operation : menu.operations.filter(\.typesText)
                .max { (probabilities[$0.optionName] ?? 0) < (probabilities[$1.optionName] ?? 0) } ?? .enterText
            operation = typing
            operationSupport = [Operation.tap, typing].reduce(0) { $0 + (probabilities[$1.optionName] ?? 0) }
        }
        var (action, targetFactors) = try compose(operation, response: response, menu: menu)
        // A missing answer or one of another type must not stop the step: `nil` keeps a tap irreversible.
        let irreversible = try? response.answers.noul(named: irreversibleQuestion)
        // Opening a memo split Jev between tap 0.46, long_press 0.28, and swipe_left 0.22 on a row it picked at 0.65:
        // sure what to act on, unsure how. Every element gesture shares that target, and a reversible one is undone by
        // going back, so the element is what the gate checks (jev-use gates only the target); the most probable
        // gesture still runs. A tap Jev did not clearly judge undoable keeps its own probability.
        if operation.actsOnElement, StepPlan.risk(of: action, irreversible: irreversible) != .irreversible {
            let onElement = menu.operations.filter(\.actsOnElement).reduce(0) { $0 + (probabilities[$1.optionName] ?? 0) }
            operationSupport = max(operationSupport, onElement)
            if let pooled = try goalTermSupport(of: action, in: response, menu: menu, goal: goal),
               let index = targetFactors.firstIndex(where: { $0.name == "element" })
            {
                targetFactors[index] = StepPlan.Factor(name: "element", value: max(targetFactors[index].value, pooled))
            }
        }
        let factors = [StepPlan.Factor(name: "operation", value: operationSupport)] + targetFactors
        return try StepPlan(
            action: action,
            confidence: probabilities[operation.optionName] ?? 0,
            support: factors.map(\.value).min() ?? 0,
            finishes: response.answers.noul(named: finishesQuestion),
            irreversible: irreversible,
            alternatives: alternatives(to: operation, in: probabilities),
            factors: factors,
            costUSD: response.usage.estimatedCostUSD,
            model: response.model,
        )
    }

    /// The operation probabilities once Jev judged the goal not yet satisfied. DONE keeps only the share of its
    /// probability that the satisfied answer backs; the rest goes to the other operations in proportion to theirs, so
    /// an operation DONE was not competing with keeps its probability.
    static func notDone(_ probabilities: [String: Double], satisfied: Double) -> [String: Double] {
        let done = Operation.done.optionName
        let doneProbability = probabilities[done] ?? 0
        let rest = 1 - doneProbability
        // Jev put everything on DONE yet judged the goal unmet: nothing else is on offer, so the step hands over.
        guard rest > 0 else { return [Operation.blocked.optionName: 1 - satisfied, done: satisfied] }
        var adjusted = probabilities.mapValues { $0 + doneProbability * (1 - satisfied) * $0 / rest }
        adjusted[done] = doneProbability * satisfied
        return adjusted
    }

    /// The two most probable other operations, for the progress line.
    static func alternatives(to operation: Operation, in probabilities: [String: Double]) -> [StepPlan.Alternative] {
        probabilities
            .filter { $0.key != operation.optionName && $0.value >= 0.05 }
            .sorted { $0.value > $1.value }
            .prefix(2)
            .map { StepPlan.Alternative(name: $0.key, probability: $0.value) }
    }

    /// The probability of every element whose label holds the goal's quoted term that the chosen one holds.
    ///
    /// A goal that names a kind of item (any red-pink colour) is met by any element of that kind, so choosing among
    /// them spread Jev's target across seven swatches (0.50 at most) without making the choice any less right.
    static func goalTermSupport(of action: AgentAction, in response: JevResponse, menu: ActionMenu, goal: String) throws -> Double? {
        let chosenLabel: String
        switch action {
        case let .tap(_, _, label), let .gesture(_, _, _, label): chosenLabel = label
        default: return nil
        }
        let terms = ScanFirst.namedTerms(in: goal).filter { chosenLabel.contains($0) }
        guard !terms.isEmpty else { return nil }
        let probabilities = try choice(elementQuestion, in: response).probabilities
        return menu.elements
            .filter { target in terms.contains { target.label.contains($0) } }
            .reduce(0) { $0 + (probabilities[$1.optionName] ?? 0) }
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
    ) throws -> (AgentAction, [StepPlan.Factor]) {
        switch operation {
        case .tap, .gesture:
            let (element, support) = try target(elementQuestion, among: menu.elements, in: response)
            let action: AgentAction = if case let .gesture(gesture) = operation {
                .gesture(gesture, alias: element.alias, role: element.role, label: element.label)
            } else {
                .tap(alias: element.alias, role: element.role, label: element.label)
            }
            return (action, [StepPlan.Factor(name: "element", value: support)])
        case .enterText, .replaceText:
            let (field, fieldSupport) = try target(fieldQuestion, among: menu.fields, in: response)
            let textAnswer = try choice(textQuestion, in: response)
            guard let text = menu.texts.first(where: { $0.name == textAnswer.value }) else {
                throw PlanningError.unknownChoice(textAnswer.value)
            }
            return (.enterText(field: field.alias, label: field.label, text: text, replacing: operation == .replaceText), [
                StepPlan.Factor(name: "field", value: fieldSupport),
                StepPlan.Factor(name: "text", value: textAnswer.confidence),
            ])
        case let .device(action):
            return (.device(action), [])
        case .wait:
            return (.wait, [])
        case .done:
            return (.done, [])
        case .blocked:
            return (.noneApplies, [])
        }
    }

    private static func choice(_ question: String, in response: JevResponse) throws -> Answer.Choice {
        guard case let .choice(answer) = response.answers[question] else { throw PlanningError.missingChoice }
        return answer
    }
}

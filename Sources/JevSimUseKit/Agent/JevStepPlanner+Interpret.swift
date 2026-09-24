import Jev

extension JevStepPlanner {
    /// Choice options are built at runtime, so the typed `ChoiceQuestion` reads do not
    /// apply: the raw answer is matched against the option names that were sent.
    static func interpret(
        _ response: JevResponse,
        actions: [AgentAction],
        gestureTargets: [GestureTarget] = [],
    ) throws -> StepPlan {
        let goalReached = try response.answers.noul(named: goalQuestion)
        guard case let .choice(choice) = response.answers[actionQuestion] else {
            throw PlanningError.missingChoice
        }
        let (action, support) = if choice.value == gestureOption {
            try composeGesture(response, gateSupport: choice.confidence, targets: gestureTargets)
        } else {
            try offered(choice, among: actions)
        }
        return StepPlan(
            goalReached: goalReached,
            action: action,
            confidence: choice.confidence,
            support: support,
            costUSD: response.usage.estimatedCostUSD,
            model: response.model,
        )
    }

    /// The offered action Jev chose, with its support.
    static func offered(_ choice: Answer.Choice, among actions: [AgentAction]) throws -> (action: AgentAction, support: Double) {
        guard let action = actions.first(where: { $0.optionName == choice.value }) else {
            throw PlanningError.unknownChoice(choice.value)
        }
        return (action, max(choice.confidence, equivalentProbability(of: action, among: actions, choice.probabilities)))
    }

    /// Probability mass of every offered option that does the same thing as `action`. Duplicate labels
    /// (two "Calendar" buttons) split the distribution without making the choice any less clear.
    static func equivalentProbability(
        of action: AgentAction,
        among actions: [AgentAction],
        _ probabilities: [String: Double],
    ) -> Double {
        actions
            .filter { $0.optionDescription == action.optionDescription }
            .reduce(0) { $0 + (probabilities[$1.optionName] ?? 0) }
    }
}

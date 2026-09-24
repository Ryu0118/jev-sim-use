import Jev

extension JevStepPlanner {
    /// Choice options are built at runtime, so the typed `ChoiceQuestion` reads do not
    /// apply: the raw answer is matched against the option names that were sent.
    static func interpret(_ response: JevResponse, actions: [AgentAction]) throws -> StepPlan {
        let goalReached = try response.answers.noul(named: goalQuestion)
        guard case let .choice(choice) = response.answers[actionQuestion] else {
            throw PlanningError.missingChoice
        }
        guard let action = actions.first(where: { $0.optionName == choice.value }) else {
            throw PlanningError.unknownChoice(choice.value)
        }
        return StepPlan(
            goalReached: goalReached,
            action: action,
            confidence: choice.confidence,
            support: max(choice.confidence, equivalentProbability(of: action, among: actions, choice.probabilities)),
            costUSD: response.usage.estimatedCostUSD,
            model: response.model,
        )
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

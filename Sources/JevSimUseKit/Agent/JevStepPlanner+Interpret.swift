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
            costUSD: response.usage.estimatedCostUSD,
        )
    }
}

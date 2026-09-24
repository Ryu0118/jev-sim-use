import Jev

/// Decides what to do on one screen. A seam so the loop can be tested without Jev.
package protocol StepPlanning: Sendable {
    /// Judges whether the goal is reached and which action to take next.
    func plan(_ request: PlanRequest) async throws -> StepPlan
}

/// Everything a planner sees for one step.
package struct PlanRequest: Sendable, Hashable {
    /// What the user wants done, in natural language.
    package var goal: String
    /// The current screen.
    package var snapshot: UISnapshot
    /// The options to choose from, in presentation order.
    package var actions: [AgentAction]
    /// The steps already taken, oldest first.
    package var history: [HistoryEntry]
}

/// A planner's judgement for one step.
package struct StepPlan: Sendable, Hashable {
    /// Probability that the goal is already reached.
    package var goalReached: Probability
    /// The action Jev ranked highest.
    package var action: AgentAction
    /// Jev's confidence in `action`, 0...1.
    package var confidence: Double
    /// What the action policy compares: `confidence`, or more when several options do the same thing
    /// (identical role and label) and split the probability between them.
    package var support: Double
    /// Estimated request cost, for logging.
    package var costUSD: Double
    /// The model version that answered, for logs.
    package var model: String

    package init(
        goalReached: Probability,
        action: AgentAction,
        confidence: Double,
        support: Double? = nil,
        costUSD: Double,
        model: String = "",
    ) {
        self.goalReached = goalReached
        self.action = action
        self.confidence = confidence
        self.support = support ?? confidence
        self.costUSD = costUSD
        self.model = model
    }
}

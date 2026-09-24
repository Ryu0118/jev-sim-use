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
    /// The operations and targets to choose from.
    package var menu: ActionMenu
    /// The steps already taken, oldest first.
    package var history: [HistoryEntry]
    /// Facts about the app from a supervisor, oldest first.
    package var notes: [String] = []
}

/// A planner's judgement for one step.
package struct StepPlan: Sendable, Hashable {
    /// The action Jev chose, composed from its operation and target answers; `.done` or `.noneApplies` to stop.
    package var action: AgentAction
    /// Jev's confidence in the operation, 0...1.
    package var confidence: Double
    /// What the action policy compares: the weakest answer the action depends on.
    package var support: Double
    /// Probability that this action, if it works, completes the goal.
    package var finishes: Probability
    /// Estimated request cost, for logging.
    package var costUSD: Double
    /// The model version that answered, for logs.
    package var model: String

    package init(
        action: AgentAction,
        confidence: Double,
        support: Double? = nil,
        finishes: Probability = Probability(clamping: 0),
        costUSD: Double,
        model: String = "",
    ) {
        self.action = action
        self.confidence = confidence
        self.support = support ?? confidence
        self.finishes = finishes
        self.costUSD = costUSD
        self.model = model
    }
}

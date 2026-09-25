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
    /// A runner-up operation and its probability.
    package struct Alternative: Sendable, Hashable {
        /// The operation's option name.
        package let name: String
        /// Its probability in the operation answer.
        package let probability: Double
    }

    /// The runner-up operations, most likely first: what Jev hesitated between.
    package var alternatives: [Alternative] = []
    /// One answer `support` depends on, named by what it chose (operation, element, field, text).
    package struct Factor: Sendable, Hashable {
        /// What the answer chose.
        package let name: String
        /// Its (pooled) probability.
        package let value: Double
    }

    /// The answers `support` is the weakest of, so a log shows which one held the action back.
    package var factors: [Factor] = []
    /// Estimated request cost, for logging.
    package var costUSD: Double
    /// The model version that answered, for logs.
    package var model: String

    package init(
        action: AgentAction,
        confidence: Double,
        support: Double? = nil,
        finishes: Probability = Probability(clamping: 0),
        alternatives: [Alternative] = [],
        factors: [Factor] = [],
        costUSD: Double,
        model: String = "",
    ) {
        self.action = action
        self.confidence = confidence
        self.support = support ?? confidence
        self.finishes = finishes
        self.alternatives = alternatives
        self.factors = factors
        self.costUSD = costUSD
        self.model = model
    }
}

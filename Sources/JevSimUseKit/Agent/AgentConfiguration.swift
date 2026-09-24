import Jev

/// What the agent should do and when it must stop.
package struct AgentConfiguration: Sendable, Hashable {
    /// The goal in natural language.
    package var goal: String
    /// Texts the agent may paste; Jev chooses among them but cannot write new text.
    package var texts: [String]
    /// Upper bound on actions taken.
    package var maxSteps: Int
    /// Stop after this many consecutive actions left the screen unchanged.
    package var stallLimit: Int
    /// Thresholds for trusting Jev's goal-reached judgement.
    package var goalPolicy: RoutingPolicy
    /// Thresholds for acting on Jev's chosen action.
    package var actionPolicy: ActionPolicy

    /// Creates a configuration; the defaults mirror sim-use's "escalate after 3 retries" guidance.
    package init(
        goal: String,
        texts: [String] = [],
        maxSteps: Int = 15,
        stallLimit: Int = 3,
        goalPolicy: RoutingPolicy = .default,
        actionPolicy: ActionPolicy = ActionPolicy(),
    ) {
        self.goal = goal
        self.texts = texts
        self.maxSteps = maxSteps
        self.stallLimit = stallLimit
        self.goalPolicy = goalPolicy
        self.actionPolicy = actionPolicy
    }
}

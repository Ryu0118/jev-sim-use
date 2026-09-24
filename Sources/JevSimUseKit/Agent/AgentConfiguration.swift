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
    /// Thresholds for acting on Jev's answers.
    package var policy: RoutingPolicy

    /// Creates a configuration; the defaults mirror sim-use's "escalate after 3 retries" guidance.
    package init(
        goal: String,
        texts: [String] = [],
        maxSteps: Int = 15,
        stallLimit: Int = 3,
        policy: RoutingPolicy = .default,
    ) {
        self.goal = goal
        self.texts = texts
        self.maxSteps = maxSteps
        self.stallLimit = stallLimit
        self.policy = policy
    }
}

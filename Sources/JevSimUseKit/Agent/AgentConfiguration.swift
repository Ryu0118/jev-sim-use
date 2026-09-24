import Jev

/// What the agent should do and when it must stop.
package struct AgentConfiguration: Sendable, Hashable {
    /// The goal in natural language.
    package var goal: String
    /// Named texts the agent may enter; Jev chooses among their names but cannot write new text.
    package var texts: [InputText]
    /// Facts about the app from a supervisor (`session tell`), shown to Jev as `notes`.
    package var notes: [String]
    /// Upper bound on actions taken.
    package var maxSteps: Int
    /// Stop after this many consecutive actions left the screen unchanged.
    package var stallLimit: Int
    /// Thresholds for acting on Jev's chosen action.
    package var actionPolicy: ActionPolicy

    /// Creates a configuration; the defaults mirror sim-use's "escalate after 3 retries" guidance.
    package init(
        goal: String,
        texts: [InputText] = [],
        notes: [String] = [],
        maxSteps: Int = 15,
        stallLimit: Int = 3,
        actionPolicy: ActionPolicy = ActionPolicy(),
    ) {
        self.goal = goal
        self.texts = texts
        self.notes = notes
        self.maxSteps = maxSteps
        self.stallLimit = stallLimit
        self.actionPolicy = actionPolicy
    }
}

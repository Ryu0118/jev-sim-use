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
    /// The operations Jev may choose from (`--actions`).
    package var allowedOperations: Set<OperationGroup>
    /// How long to keep reading after an action that left the screen as it was, before calling it ineffective.
    package var unchangedWait: Duration
    /// How long a `wait` action pauses.
    package var waitDuration: Duration
    /// How long to keep reading for a screen that moves on before handing over.
    package var handOverWait: Duration
    /// How long one cycle (read, plan, act) may take before it is cut off; `nil` turns the cut-off off.
    package var stepTimeout: Duration?
    /// Readings taken after an action that left the screen as it was, however long `unchangedWait` has run.
    package var minUnchangedReads: Int
    /// Readings taken before a hand-over, however long `handOverWait` has run.
    package var minHandOverReads: Int
    /// How long the screen image must stay unchanged to count as still, with a screen-change watcher.
    package var quietPeriod: Duration
    /// How long to wait for the screen image to go still after it changed, with a screen-change watcher.
    package var settleWait: Duration
    /// The longest one wait (after an action, or before a hand-over) may run, minimum read counts included; `nil` sets
    /// no cap.
    package var maxWait: Duration?

    /// Creates a configuration; the defaults mirror sim-use's "escalate after 3 retries" guidance.
    package init(
        goal: String,
        texts: [InputText] = [],
        notes: [String] = [],
        maxSteps: Int = 15,
        stallLimit: Int = 3,
        actionPolicy: ActionPolicy = ActionPolicy(),
        allowedOperations: Set<OperationGroup> = OperationGroup.all,
        unchangedWait: Duration = .zero,
        waitDuration: Duration = .zero,
        handOverWait: Duration = .zero,
        stepTimeout: Duration? = nil,
        minUnchangedReads: Int = 1,
        minHandOverReads: Int = 1,
        quietPeriod: Duration = .zero,
        settleWait: Duration = .zero,
        maxWait: Duration? = nil,
    ) {
        self.goal = goal
        self.texts = texts
        self.notes = notes
        self.maxSteps = maxSteps
        self.stallLimit = stallLimit
        self.actionPolicy = actionPolicy
        self.allowedOperations = allowedOperations
        self.unchangedWait = unchangedWait
        self.waitDuration = waitDuration
        self.handOverWait = handOverWait
        self.stepTimeout = stepTimeout
        self.minUnchangedReads = minUnchangedReads
        self.minHandOverReads = minHandOverReads
        self.quietPeriod = quietPeriod
        self.settleWait = settleWait
        self.maxWait = maxWait
    }
}

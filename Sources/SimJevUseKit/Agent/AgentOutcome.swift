/// How a run ended.
public enum AgentOutcome: Sendable, Hashable, CustomStringConvertible {
    /// Jev judged the goal reached after `steps` actions.
    case goalReached(steps: Int)
    /// `maxSteps` actions were taken without reaching the goal.
    case stepLimitReached(steps: Int)
    /// Several actions in a row left the screen unchanged.
    case stalled(steps: Int)
    /// Jev was not confident enough to act; a person should take over.
    case escalated(step: Int, action: AgentAction, confidence: Double)
    /// The app under test disappeared or showed a crash dialog.
    case appCrashed(detail: String)

    /// Whether the goal was reached.
    public var isSuccess: Bool {
        if case .goalReached = self {
            true
        } else {
            false
        }
    }

    /// A one-line summary of how the run ended.
    public var description: String {
        switch self {
        case let .goalReached(steps): "Goal reached after \(steps) action(s)."
        case let .stepLimitReached(steps): "Stopped: the step limit of \(steps) was reached."
        case let .stalled(steps): "Stopped after \(steps) action(s): the screen stopped changing."
        case let .escalated(step, action, confidence):
            "Stopped at step \(step): Jev's best action (\(action)) had confidence "
                + "\(confidence.formatted(.number.precision(.fractionLength(2)))), below the threshold."
        case let .appCrashed(detail): "Stopped: \(detail)"
        }
    }
}

/// How a run ended.
package enum AgentOutcome: Sendable, Hashable, CustomStringConvertible {
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
    /// Jev judged that none of the offered actions advances the goal.
    case noActionFits(step: Int)
    /// Jev chose DONE with support below `ActionPolicy.doneMinimum`: probably reached, but not enough to claim success.
    case goalProbablyReached(steps: Int, probability: Double)

    /// Whether the goal was reached.
    package var isSuccess: Bool {
        if case .goalReached = self {
            true
        } else {
            false
        }
    }

    /// Whether Jev chose to stop on what it saw, rather than a limit, a crash, or success ending the run.
    var isHandOver: Bool {
        switch self {
        case .escalated, .noActionFits, .goalProbablyReached: true
        default: false
        }
    }

    /// A one-line summary of how the run ended.
    package var description: String {
        switch self {
        case let .goalReached(steps): "Goal reached after \(steps) action(s)."
        case let .stepLimitReached(steps): "Stopped: the step limit of \(steps) was reached."
        case let .stalled(steps): "Stopped after \(steps) action(s): the screen stopped changing."
        case let .escalated(step, action, confidence):
            "Stopped at step \(step): Jev's best action (\(action)) had confidence "
                + "\(confidence.formatted(.number.precision(.fractionLength(2)))), below the threshold."
        case let .appCrashed(detail): "Stopped: \(detail)"
        case let .goalProbablyReached(steps, probability):
            "Stopped after \(steps) action(s): the goal is probably reached (p="
                + "\(probability.formatted(.number.precision(.fractionLength(2))))), but not surely; check the screen."
        case let .noActionFits(step): "Stopped at step \(step): no offered action advances the goal on this screen."
        }
    }
}

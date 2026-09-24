/// Progress reported while the agent runs.
public enum AgentEvent: Sendable, Hashable, CustomStringConvertible {
    /// A plan was made for `step`.
    case planned(step: Int, plan: StepPlan)
    /// `action` is about to run although confidence is in the confirm band.
    case lowConfidence(step: Int, confidence: Double)

    /// A single progress line for the console.
    public var description: String {
        switch self {
        case let .planned(step, plan):
            "[\(step)] \(plan.action) (confidence \(Self.format(plan.confidence)), "
                + "goal reached p=\(Self.format(plan.goalReached.value)), ~$\(plan.costUSD.formatted())"
                + ")"
        case let .lowConfidence(step, confidence):
            "[\(step)] acting with moderate confidence \(Self.format(confidence))"
        }
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }
}

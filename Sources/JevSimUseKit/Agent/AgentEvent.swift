/// Progress reported while the agent runs.
package enum AgentEvent: Sendable, Hashable, CustomStringConvertible {
    /// A plan was made for `step`.
    case planned(step: Int, plan: StepPlan)
    /// `action` is about to run although confidence is in the confirm band.
    case lowConfidence(step: Int, confidence: Double)
    /// Jev found nothing, or was too unsure to act, so code explores with `action`.
    case exploring(step: Int, action: AgentAction)

    /// A single progress line for the console.
    package var description: String {
        switch self {
        case let .planned(step, plan):
            "[\(step)] \(plan.action) (support \(Self.format(plan.support)), "
                + "goal reached p=\(Self.format(plan.goalReached.value)), ~$\(plan.costUSD.formatted())"
                + (plan.model.isEmpty ? ")" : ", \(plan.model))")
        case let .lowConfidence(step, confidence):
            "[\(step)] acting with moderate confidence \(Self.format(confidence))"
        case let .exploring(step, action):
            "[\(step)] exploring instead: \(action)"
        }
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }
}

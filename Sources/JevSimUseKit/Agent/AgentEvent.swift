/// Progress reported while the agent runs.
package enum AgentEvent: Sendable, Hashable, CustomStringConvertible {
    /// A plan was made for `step`.
    case planned(step: Int, plan: StepPlan)
    /// The goal names an item not on this list, so code scrolls once before Jev opens an unnamed section.
    case scanning(step: Int)
    /// The step would hand over, so it is asked again with the screen's accessibility hints.
    case retryingWithHints(step: Int)
    /// `action` is about to run although confidence is in the confirm band.
    case lowConfidence(step: Int, confidence: Double)

    /// A single progress line for the console.
    package var description: String {
        switch self {
        case let .planned(step, plan):
            "[\(step)] \(plan.action) (support \(Self.format(plan.support))\(Self.breakdown(plan.factors)), "
                + "finishes p=\(Self.format(plan.finishes.value))\(Self.irreversibility(of: plan)), "
                + "~$\(plan.costUSD.formatted())"
                + (plan.model.isEmpty ? "" : ", \(plan.model)")
                + plan.alternatives.map { "; also \($0.name) \(Self.format($0.probability))" }.joined() + ")"
        case let .scanning(step):
            "[\(step)] the goal's item is not on screen; scrolling this list once before opening another section"
        case let .retryingWithHints(step):
            "[\(step)] unsure; asking again with the screen's accessibility hints"
        case let .lowConfidence(step, confidence):
            "[\(step)] acting with moderate confidence \(Self.format(confidence))"
        }
    }

    /// The answers behind a support that depends on more than one, so a log shows which one was lowest.
    private static func breakdown(_ factors: [StepPlan.Factor]) -> String {
        guard factors.count > 1 else { return "" }
        return " [" + factors.map { "\($0.name) \(format($0.value))" }.joined(separator: ", ") + "]"
    }

    /// A tap's irreversibility answer, which decides whether it faces the irreversible bar.
    private static func irreversibility(of plan: StepPlan) -> String {
        guard case .tap = plan.action else { return "" }
        return ", irreversible p=" + (plan.irreversible.map { format($0.value) } ?? "none")
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }
}

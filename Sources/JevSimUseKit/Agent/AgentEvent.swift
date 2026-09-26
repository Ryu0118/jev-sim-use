/// Progress reported while the agent runs.
package enum AgentEvent: Sendable, Hashable, CustomStringConvertible {
    /// A plan was made for `step`.
    case planned(step: Int, plan: StepPlan)
    /// The step would hand over, so it is asked again with the screen's accessibility hints.
    case retryingWithHints(step: Int)
    /// The step would hand over on a screen that did not move on, so the same request is asked once more.
    case resampling(step: Int)
    /// `action` is about to run although confidence is in the confirm band.
    case lowConfidence(step: Int, confidence: Double)
    /// `step` ended, by acting or by stopping, and `timing` says where its time went.
    case timed(step: Int, timing: StepTiming)

    /// A single progress line for the console.
    package var description: String {
        switch self {
        case let .planned(step, plan):
            "[\(step)] \(plan.action) (support \(Self.format(plan.support))\(Self.breakdown(plan.factors)), "
                + "finishes p=\(Self.format(plan.finishes.value))\(Self.irreversibility(of: plan)), "
                + "~$\(plan.costUSD.formatted())"
                + (plan.model.isEmpty ? "" : ", \(plan.model)")
                + plan.alternatives.map { "; also \($0.name) \(Self.format($0.probability))" }.joined() + ")"
        case let .retryingWithHints(step):
            "[\(step)] unsure; asking again with the screen's accessibility hints"
        case let .resampling(step):
            "[\(step)] about to hand over on an unchanged screen; asking the same request once more"
        case let .lowConfidence(step, confidence):
            "[\(step)] acting with moderate confidence \(Self.format(confidence))"
        case let .timed(step, timing):
            "[\(step)] took \(StepTiming.format(timing.total)) (\(timing))"
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

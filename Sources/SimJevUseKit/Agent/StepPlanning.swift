import Jev

/// Decides what to do on one screen. A seam so the loop can be tested without Jev.
public protocol StepPlanning: Sendable {
    /// Judges whether the goal is reached and which action to take next.
    func plan(_ request: PlanRequest) async throws -> StepPlan
}

/// Everything a planner sees for one step.
public struct PlanRequest: Sendable, Hashable {
    /// What the user wants done, in natural language.
    public var goal: String
    /// The current screen.
    public var snapshot: UISnapshot
    /// The options to choose from, in presentation order.
    public var actions: [AgentAction]
    /// Descriptions of the actions already taken, oldest first.
    public var history: [String]
}

/// A planner's judgement for one step.
public struct StepPlan: Sendable, Hashable {
    /// Probability that the goal is already reached.
    public var goalReached: Probability
    /// The action Jev ranked highest.
    public var action: AgentAction
    /// Jev's confidence in `action`, 0...1.
    public var confidence: Double
    /// Estimated request cost, for logging.
    public var costUSD: Double
}

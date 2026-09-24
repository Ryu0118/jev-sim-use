/// What the loop does after a plan: stop with an outcome, or run an action.
enum StepDecision: Sendable, Equatable {
    case stop(AgentOutcome)
    case act(AgentAction)
}

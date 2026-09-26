/// Where a run of `AgentLoop` stands between readings. Each state has one transition in `AgentLoop+Transitions`, which
/// returns the next state; `AgentLoopContext` carries what outlives a single step.
enum AgentLoopState {
    /// Read the screen, or take `pending`, a reading already in hand, while confirming readings still overlap planning.
    case observing(pending: ScreenObservation?)
    /// Ask Jev about the reading, with a confirming reading taken meanwhile.
    case planning(ScreenObservation)
    /// Turn a plan into an action, a stop, or another reading.
    case deciding(PlannedStep)
    /// The run is over.
    case finished(AgentOutcome)
}

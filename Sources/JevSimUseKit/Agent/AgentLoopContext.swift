/// What a run of `AgentLoop` carries from one step to the next.
struct AgentLoopContext {
    /// History, loop detection, and the other per-run bookkeeping.
    var progress: AgentProgress
    /// The screen the last action was taken on; `nil` once a plan's target was gone from the screen.
    var actedOn: UISnapshot?
    /// Times this step was planned again because the screen moved on while Jev decided to stop.
    var staleReplans = 0
    /// Confirming readings in a row that disagreed with the planned one.
    var disagreements = 0

    /// Whether a confirming reading runs while Jev plans. After `AgentLoop.disagreementLimit` disagreements the loop
    /// reads until two readings agree instead, and plans without one.
    var overlapped: Bool {
        disagreements < AgentLoop.disagreementLimit
    }

    /// Records `action`, taken on `snapshot`: the next step starts with no re-plans and no disagreements.
    mutating func acted(_ action: AgentAction, disappeared: [String], on snapshot: UISnapshot) {
        progress.recordAction(action, disappeared: disappeared)
        actedOn = snapshot
        staleReplans = 0
        disagreements = 0
    }

    /// The confirming reading `fresh` disagreed with the planned one: plan again on it.
    mutating func disagreed(pending fresh: ScreenObservation) -> AgentLoopState {
        disagreements += 1
        return .observing(pending: fresh)
    }
}

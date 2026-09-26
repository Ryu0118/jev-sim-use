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
    /// Whether this step's hand-over was already asked once more.
    var resampled = false
    /// Where the current step's time has gone so far.
    var timing = StepTiming()
    /// Where the finished steps' time went.
    var finishedTiming = StepTiming()

    /// Whether a confirming reading runs while Jev plans. After `AgentLoop.disagreementLimit` disagreements the loop
    /// reads until two readings agree instead, and plans without one.
    var overlapped: Bool {
        disagreements < AgentLoop.disagreementLimit
    }

    /// Records `action`, taken on `snapshot`, with the step's timing, and returns the step's number and timing: the
    /// next step starts with no re-plans, no disagreements, and no time spent.
    mutating func acted(_ action: AgentAction, disappeared: [String], on snapshot: UISnapshot) -> (step: Int, timing: StepTiming) {
        let step = (progress.nextStep, timing)
        progress.recordAction(action, disappeared: disappeared, timing: timing)
        actedOn = snapshot
        staleReplans = 0
        disagreements = 0
        resampled = false
        finishedTiming += timing
        timing = StepTiming()
        return step
    }

    /// The confirming reading `fresh` disagreed with the planned one: plan again on it.
    mutating func disagreed(pending fresh: ScreenObservation) -> AgentLoopState {
        disagreements += 1
        return .observing(pending: fresh)
    }
}

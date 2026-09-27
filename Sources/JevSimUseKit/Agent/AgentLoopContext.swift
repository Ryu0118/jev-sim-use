/// What a run of `AgentLoop` carries from one step to the next.
struct AgentLoopContext: Sendable {
    /// History, loop detection, and the other per-run bookkeeping.
    var progress: AgentProgress
    /// The screen the last action was taken on; `nil` once a plan's target was gone from the screen.
    var actedOn: UISnapshot?
    /// The field and text of the last action when it typed, until the next reading shows whether the text landed.
    var typing: (field: Int, text: InputText)?
    /// Times this step was planned again because the screen moved on while Jev decided to stop.
    var staleReplans = 0
    /// Confirming readings in a row that disagreed with the planned one.
    var disagreements = 0
    /// Where the current step's time has gone so far.
    var timing = StepTiming()
    /// Where the finished steps' time went.
    var finishedTiming = StepTiming()
    /// Cycles in a row cut off by the step timeout.
    var consecutiveCuts = 0
    /// What the current cycle is doing, for the step timeout.
    let watch = StepWatch()

    /// Runs `body`, adding its time to `part` of the step's timing and noting that the cycle waits on it.
    mutating func timed<T>(_ part: WritableKeyPath<StepTiming, Double> & Sendable, _ body: () async throws -> T) async rethrows -> T {
        watch.enter(part)
        return try await timing.add(to: part, body)
    }

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
        typing = if case let .enterText(field, _, text, _) = action {
            (field, text)
        } else {
            nil
        }
        staleReplans = 0
        disagreements = 0
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

/// A plan with the readings it was made on and checked against.
struct PlannedStep: Sendable {
    /// The reading Jev planned on.
    let observation: ScreenObservation
    /// The confirming reading taken while Jev planned, or `observation` when none was taken.
    let fresh: ScreenObservation
    /// Jev's plan for `observation`.
    let plan: StepPlan
    /// Whether a confirming reading ran alongside planning (see `AgentLoopContext.overlapped`).
    let overlapped: Bool
    /// Whether the two readings agree: the same elements in the same places (values aside, as relative times tick),
    /// or the same elements and states wherever they sit (a tab switch still animating the same content).
    let settled: Bool
    /// When planning began, before the confirming reading was taken: a change after it may not be in that reading.
    let plannedAt: ContinuousClock.Instant
}

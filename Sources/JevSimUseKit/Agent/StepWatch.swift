import Synchronization

/// What the current cycle is doing, kept outside the cycle so a cut-off can still tell what it waited on, the action
/// that was in flight, and where the time went. Shared by every copy of one run's `AgentLoopContext`.
final class StepWatch: Sendable {
    private struct State {
        var deadline = ContinuousClock.now
        var part: WritableKeyPath<StepTiming, Double> & Sendable = \StepTiming.read
        var partStart = ContinuousClock.now
        var timing = StepTiming()
        var action: AgentAction?
        var plannedOn: UISnapshot?
        var latest: AgentLoopContext?
    }

    private let state = Mutex(State())

    /// Starts a cycle that must finish within `timeout`.
    func start(timeout: Duration) {
        state.withLock { state in
            let now = ContinuousClock.now
            state = State(deadline: now + timeout, partStart: now)
        }
    }

    /// Notes that the cycle now waits on `part`.
    func enter(_ part: WritableKeyPath<StepTiming, Double> & Sendable) {
        state.withLock { state in
            let now = ContinuousClock.now
            state.timing[keyPath: state.part] += (now - state.partStart) / .seconds(1)
            state.part = part
            state.partStart = now
        }
    }

    /// Keeps `context` as it stood after the cycle's last finished transition: the readings it recorded stay recorded
    /// when the cycle is cut off later.
    func finished(_ context: AgentLoopContext) {
        state.withLock { $0.latest = context }
    }

    /// The context after the cut-off cycle's last finished transition, if one finished.
    var latest: AgentLoopContext? {
        state.withLock { $0.latest }
    }

    /// Notes the action being taken on `snapshot`, or `nil` once it returned.
    func acting(_ action: AgentAction?, on snapshot: UISnapshot?) {
        state.withLock { state in
            state.action = action
            state.plannedOn = snapshot
        }
    }

    /// Moves the deadline out by `duration`, for a wait whose length its own setting bounds.
    func extend(by duration: Duration) {
        state.withLock { $0.deadline += duration }
    }

    /// Returns once the deadline has passed, rechecking it as waits extend it.
    func sleepUntilDeadline() async throws {
        while true {
            let remaining = state.withLock { $0.deadline } - .now
            guard remaining > .zero else { return }
            try await Task.sleep(for: min(remaining, .milliseconds(100)))
        }
    }

    /// What the cut-off cycle was doing: the part it waited on, the action in flight and the screen it was planned on,
    /// and the cycle's timing up to now.
    func cutOff() -> (part: StepTiming.Part, action: AgentAction?, plannedOn: UISnapshot?, timing: StepTiming) {
        state.withLock { state in
            var timing = state.timing
            timing[keyPath: state.part] += (ContinuousClock.now - state.partStart) / .seconds(1)
            return (StepTiming.Part(state.part), state.action, state.plannedOn, timing)
        }
    }
}

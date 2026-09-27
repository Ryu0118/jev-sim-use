/// The step timeout: one cycle (read, plan, act) that does not finish in time is cut off and planned again once.
extension AgentLoop {
    /// Runs the transition out of `state`.
    func transition(from state: AgentLoopState, context: inout AgentLoopContext) async throws -> AgentLoopState {
        switch state {
        case let .observing(pending): try await observe(pending: pending, context: &context)
        case let .planning(observation): try await planStep(on: observation, context: &context)
        case let .deciding(step): try await decideStep(step, context: &context)
        case .finished: state
        }
    }

    /// Runs one cycle, from a reading until the loop reads again or finishes, on its own copy of `context`.
    func cycle(from state: AgentLoopState, context: AgentLoopContext) async throws -> (AgentLoopState, AgentLoopContext) {
        var state = state
        var context = context
        repeat {
            state = try await transition(from: state, context: &context)
            context.watch.finished(context)
        } while !state.endsCycle
        return (state, context)
    }

    /// Runs one cycle within its deadline, or cuts it off: the cycle is cancelled, which kills the sim-use command or
    /// Jev request it waits on, and the step is recorded in the words of what it waited on. The loop then reads and
    /// plans again rather than sending a cut-off action once more, since that action may already have landed. A sim-use
    /// call that timed out inside the cycle (see `SimUseClient+Daemon`, the only place that stops the daemon) ends it
    /// the same way. Two such hangs in a row end the run.
    ///
    /// The deadline is `--step-timeout` or, when longer, room for three reads, the longest action, and Jev at the
    /// device's own pace, so a hung sim-use call always meets its own deadline first. The unchanged-screen and hand-over
    /// waits and `wait` stand outside it, since each of their reads has a deadline of its own; a re-plan on a screen
    /// that moved on is a cycle of its own.
    func timedCycle(from state: AgentLoopState, context: AgentLoopContext) async throws -> (AgentLoopState, AgentLoopContext) {
        guard let floor = configuration.stepTimeout else { return try await cycle(from: state, context: context) }
        var context = context
        let deadlines = driver.callDeadlines()
        let timeout = max(floor, deadlines.map { $0.read * 3 + $0.action + Self.jevAllowance(context.recentJev) } ?? floor)
        context.timing.readBaseline = deadlines?.stretchedReadBaseline.map { $0 / .seconds(1) }
        let watch = context.watch
        watch.start(timeout: timeout)
        let finished: (AgentLoopState, AgentLoopContext)?
        do {
            finished = try await withThrowingTaskGroup(of: (AgentLoopState, AgentLoopContext)?.self) { [context] group in
                group.addTask { try await cycle(from: state, context: context) }
                group.addTask {
                    try await watch.sleepUntilDeadline()
                    return nil
                }
                defer { group.cancelAll() }
                return try await group.next() ?? nil
            }
        } catch let SimUseError.callTimedOut(_, seconds, stopped) {
            return hang(context: context, seconds: Int(seconds.rounded(.up)), daemonStopped: stopped)
        }
        if let (next, done) = finished {
            var context = done
            context.consecutiveCuts = 0
            return (next, context)
        }
        return hang(context: context, seconds: Int((timeout / .seconds(1)).rounded(.up)), daemonStopped: nil)
    }

    /// Jev's room in a cycle: eight times its median on recent steps, at least 10 s.
    static func jevAllowance(_ recent: [Double]) -> Duration {
        let median = recent.isEmpty ? 0 : recent.sorted()[recent.count / 2]
        return max(.seconds(10), .milliseconds(Int(median * 8000)))
    }

    /// Records a cycle that hung on the context its last finished transition left, or on `context`, the one it started
    /// from, and decides whether to go on. `daemonStopped` is `nil` for a cut by the cycle's deadline, which leaves the
    /// daemon alone.
    private func hang(context: AgentLoopContext, seconds: Int, daemonStopped: Bool?) -> (AgentLoopState, AgentLoopContext) {
        var context = context.watch.latest ?? context
        let (part, action, plannedOn, timing) = context.watch.cutOff()
        let step = context.progress.nextStep
        let retrying = context.consecutiveCuts + 1 < Self.cutLimit
        report(.stepCutOff(step: step, waitingOn: part, seconds: seconds, daemonStopped: daemonStopped, retrying: retrying))
        let description = if let action {
            "\(action) - cut off after \(seconds) s before it returned; it may or may not have landed"
        } else {
            "Nothing - the step was cut off after \(seconds) s while waiting on \(part.rawValue)"
        }
        context.progress.recordCutOff(description, timing: timing)
        report(.timed(step: step, timing: timing))
        context.finishedTiming += timing
        context.timing = StepTiming()
        // A cut action may still show its effect, so the next reading waits for a change as after any action.
        context.actedOn = plannedOn
        context.staleReplans = 0
        context.disagreements = 0
        context.consecutiveCuts += 1
        guard retrying else {
            return (.finished(.stepTimedOut(step: step, waitingOn: part, seconds: seconds)), context)
        }
        return (.observing(pending: nil), context)
    }

    /// Cycles in a row cut off before the run ends.
    static let cutLimit = 2

    /// The default `--step-timeout`, the cycle deadline's floor: a healthy cycle took 1-8 s, its waits aside.
    package static let defaultStepTimeout: Duration = .seconds(20)
}

extension AgentLoopState {
    /// Whether the loop reads again or is done: where one cycle ends.
    var endsCycle: Bool {
        switch self {
        case .observing, .finished: true
        case .planning, .deciding: false
        }
    }
}

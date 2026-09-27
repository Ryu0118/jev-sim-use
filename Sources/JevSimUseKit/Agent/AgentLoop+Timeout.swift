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

    /// Runs one cycle within `configuration.stepTimeout`, or cuts it off: the cycle is cancelled, which kills the
    /// sim-use command or Jev request it waits on, the device's sim-use daemon is stopped, and the step is recorded in
    /// the words of what it waited on. The loop then reads and plans again rather than sending a cut-off action once
    /// more, since that action may already have landed. A second cut in a row ends the run.
    ///
    /// A cycle re-plans on a screen that moved on as its own cycle, so two such re-plans with their hand-over waits do
    /// not add up on one clock; the hand-over wait and a `wait` action move the deadline by their own settings.
    func timedCycle(from state: AgentLoopState, context: AgentLoopContext) async throws -> (AgentLoopState, AgentLoopContext) {
        guard let timeout = configuration.stepTimeout else { return try await cycle(from: state, context: context) }
        let watch = context.watch
        watch.start(timeout: timeout)
        let finished: (AgentLoopState, AgentLoopContext)? = try await withThrowingTaskGroup(
            of: (AgentLoopState, AgentLoopContext)?.self,
        ) { group in
            group.addTask { try await cycle(from: state, context: context) }
            group.addTask {
                try await watch.sleepUntilDeadline()
                return nil
            }
            defer { group.cancelAll() }
            return try await group.next() ?? nil
        }
        if let (next, done) = finished {
            var context = done
            context.consecutiveCuts = 0
            return (next, context)
        }
        return await cutOff(context: context, seconds: Int(timeout / .seconds(1)))
    }

    /// Records the cut-off cycle on the context its last finished transition left, or on `context`, the one it started
    /// from, and decides whether to go on.
    private func cutOff(context: AgentLoopContext, seconds: Int) async -> (AgentLoopState, AgentLoopContext) {
        var context = context.watch.latest ?? context
        let (part, action, plannedOn, timing) = context.watch.cutOff()
        let stopped = await driver.stopDaemon()
        let step = context.progress.nextStep
        let retrying = context.consecutiveCuts + 1 < Self.cutLimit
        report(.stepCutOff(step: step, waitingOn: part, seconds: seconds, daemonStopped: stopped, retrying: retrying))
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

    /// The default `--step-timeout`: a healthy cycle took 1-8 s, a hand-over's wait aside.
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

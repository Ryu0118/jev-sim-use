/// One transition per `AgentLoopState`.
extension AgentLoop {
    /// Reads the screen after the last action, or takes the pending reading, and records it.
    func observe(pending: ScreenObservation?, context: inout AgentLoopContext) async throws -> AgentLoopState {
        try Task.checkCancellation()
        // Falling back discards a pending reading: it was one of the readings that kept disagreeing.
        let observation = if let pending, context.overlapped {
            pending
        } else {
            try await observeAfterAction(on: context.actedOn, settled: !context.overlapped)
        }
        if let outcome = context.progress.record(observation, stallLimit: configuration.stallLimit) {
            return .finished(outcome)
        }
        return .planning(observation)
    }

    /// Plans on `observation` while a confirming reading runs, and taps a stable bar item without waiting for it.
    func planStep(on observation: ScreenObservation, context: inout AgentLoopContext) async throws -> AgentLoopState {
        let overlapped = context.overlapped
        // The first reading after an action may be mid-transition, so a second one runs while Jev plans and decides
        // whether the plan still applies (see `confirmed`). It replaced reading until two readings agreed before
        // planning, which cost a whole read on every step.
        let confirmation = overlapped ? Task { try await driver.observe() } : nil
        let plan: StepPlan
        do {
            plan = try await self.plan(for: observation.snapshot, progress: context.progress)
        } catch {
            confirmation?.cancel()
            throw error
        }
        // A tap on a bar item that sat unchanged in the same place before and after the last action does not wait for
        // the confirming reading: that item cannot be mid-transition. The reading still finishes before the next one
        // starts, and only its report of apps that disappeared counts.
        if overlapped,
           let target = stableBarTarget(of: plan, on: observation.snapshot, before: context.actedOn, progress: context.progress),
           case let .act(action) = decide(on: plan, progress: context.progress)
        {
            let disappeared = try await driver.tapWhereShown(target, on: observation.snapshot)
            let late = try await confirmation?.value
            context.acted(action, disappeared: disappeared + (late?.disappearedApps ?? []), on: observation.snapshot)
            return .observing(pending: nil)
        }
        let fresh = try await confirmation?.value ?? observation
        if overlapped, !fresh.disappearedApps.isEmpty,
           let outcome = context.progress.record(fresh, stallLimit: configuration.stallLimit)
        {
            return .finished(outcome)
        }
        let settled = fresh.snapshot.layout == observation.snapshot.layout
            || fresh.snapshot.identity == observation.snapshot.identity
        return .deciding(PlannedStep(observation: observation, fresh: fresh, plan: plan, overlapped: overlapped, settled: settled))
    }

    /// Turns the plan, asked again with hints when it would hand over, into a stop or an action.
    func decideStep(_ step: PlannedStep, context: inout AgentLoopContext) async throws -> AgentLoopState {
        var decision = decide(on: step.plan, progress: context.progress)
        if shouldRetryWithHints(decision, on: step.observation.snapshot) {
            report(.retryingWithHints(step: context.progress.nextStep))
            let hinted = try await plan(for: step.observation.snapshot, progress: context.progress, withHints: true)
            decision = decide(on: hinted, progress: context.progress)
        }
        return switch decision {
        case let .stop(outcome): try await stop(with: outcome, after: step, context: &context)
        case let .act(action): try await act(action, after: step, context: &context)
        }
    }

    /// Ends the run with `outcome`, unless the readings disagree or the screen moves on before a hand-over.
    func stop(with outcome: AgentOutcome, after step: PlannedStep, context: inout AgentLoopContext) async throws
        -> AgentLoopState
    {
        // DONE on a screen still changing could claim a goal the settled screen does not show.
        guard step.settled else { return context.disagreed(pending: step.fresh) }
        // A saved item can reach a list a second after the screen changed: Jev, planning on the list without it,
        // scrolled at 0.40 and stopped. Before handing over, keep reading briefly and plan again if the screen moved on
        // (jev-ultrafast checks freshness the same way), a bounded number of times per step.
        if context.staleReplans < Self.staleReplanLimit, outcome.isHandOver,
           let again = try await reading(changedFrom: step.fresh.snapshot)
        {
            context.staleReplans += 1
            return .observing(pending: again)
        }
        return .finished(outcome)
    }

    /// Takes `action` on the confirming reading, or plans again when its target is no longer where it was planned.
    func act(_ action: AgentAction, after step: PlannedStep, context: inout AgentLoopContext) async throws -> AgentLoopState {
        let target = if step.overlapped {
            confirmed(action, planned: step.observation.snapshot, fresh: step.fresh.snapshot, progress: context.progress)
        } else {
            try await isStillCurrent(step.observation.snapshot, progress: context.progress) ? action : nil
        }
        guard let target else {
            context.disagreements += step.overlapped ? 1 : 0
            context.actedOn = nil
            return .observing(pending: step.overlapped ? step.fresh : nil)
        }
        if !step.settled, step.fresh.snapshot.identity != step.observation.snapshot.identity,
           let outcome = context.progress.record(step.fresh, stallLimit: configuration.stallLimit)
        {
            return .finished(outcome)
        }
        let (performed, disappeared) = try await perform(target, on: step.fresh.snapshot)
        context.acted(performed, disappeared: disappeared, on: step.fresh.snapshot)
        return .observing(pending: nil)
    }
}

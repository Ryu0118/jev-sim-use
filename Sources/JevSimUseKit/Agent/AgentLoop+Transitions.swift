/// One transition per `AgentLoopState`.
extension AgentLoop {
    /// Reads the screen after the last action, or takes the pending reading, and records it.
    func observe(pending: ScreenObservation?, context: inout AgentLoopContext) async throws -> AgentLoopState {
        try Task.checkCancellation()
        // Falling back discards a pending reading: it was one of the readings that kept disagreeing.
        let (actedOn, settled) = (context.actedOn, !context.overlapped)
        let observation = if let pending, context.overlapped {
            pending
        } else {
            try await context.timing.add(to: \.read) { try await observeAfterAction(on: actedOn, settled: settled) }
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
        let progress = context.progress
        do {
            plan = try await context.timing.add(to: \.jev) { try await self.plan(for: observation.snapshot, progress: progress) }
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
            let disappeared = try await context.timing.add(to: \.act) {
                try await driver.tapWhereShown(target, on: observation.snapshot)
            }
            let late = try await context.timing.add(to: \.read) { try await confirmation?.value }
            acted(action, disappeared: disappeared + (late?.disappearedApps ?? []), on: observation.snapshot, context: &context)
            return .observing(pending: nil)
        }
        // Only the wait after Jev answered counts: the rest of the confirming read ran under Jev's request.
        let fresh = try await context.timing.add(to: \.read) { try await confirmation?.value } ?? observation
        // The confirming reading follows the planned one with no action between: what changed is changing on its own.
        if confirmation != nil {
            context.progress.noteReading(fresh.snapshot)
        }
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
        var hinted = false
        if shouldRetryWithHints(decision, on: step.observation.snapshot) {
            hinted = true
            report(.retryingWithHints(step: context.progress.nextStep))
            let progress = context.progress
            let hinted = try await context.timing.add(to: \.jev) {
                try await plan(for: step.observation.snapshot, progress: progress, withHints: true)
            }
            decision = decide(on: hinted, progress: context.progress)
        }
        return switch decision {
        case let .stop(outcome): try await stop(with: outcome, after: step, hinted: hinted, context: &context)
        case let .act(action): try await act(action, after: step, context: &context)
        }
    }

    /// Ends the run with `outcome`, unless the readings disagree, the screen moves on before a hand-over, or the
    /// hand-over's one resample (asked with hints when `hinted`) acts.
    func stop(with outcome: AgentOutcome, after step: PlannedStep, hinted: Bool, context: inout AgentLoopContext) async throws
        -> AgentLoopState
    {
        // DONE on a screen still changing could claim a goal the settled screen does not show.
        guard step.settled else { return context.disagreed(pending: step.fresh) }
        // A saved item can reach a list a second after the screen changed: Jev, planning on the list without it,
        // scrolled at 0.40 and stopped. Before handing over, keep reading briefly and plan again if the screen moved on
        // (jev-ultrafast checks freshness the same way), a bounded number of times per step.
        guard context.staleReplans < Self.staleReplanLimit, outcome.isHandOver else { return .finished(outcome) }
        let (again, changed) = try await context.timing.add(to: \.read) { try await reading(changedFrom: step.fresh.snapshot) }
        // An app that disappeared while the wait read is a crash, whether or not the screen moved on.
        if !again.disappearedApps.isEmpty, let crash = context.progress.record(again, stallLimit: configuration.stallLimit) {
            return .finished(crash)
        }
        guard changed else { return try await resample(outcome, after: step, hinted: hinted, context: &context) }
        context.staleReplans += 1
        return .observing(pending: again)
    }

    /// Asks the request behind a hand-over on an unchanged screen once more, and acts on the new plan when it clears
    /// the bar. Jev answered byte-identical requests with BLOCKED anywhere from 0.09 to 0.53, so one sample decided
    /// too many hand-overs. At most once per step, and only ever toward an action: a DONE that only the second sample
    /// gives, or another stop, keeps the first hand-over.
    func resample(_ outcome: AgentOutcome, after step: PlannedStep, hinted: Bool, context: inout AgentLoopContext) async throws
        -> AgentLoopState
    {
        guard !context.resampled else { return .finished(outcome) }
        context.resampled = true
        report(.resampling(step: context.progress.nextStep))
        let progress = context.progress
        let plan = try await context.timing.add(to: \.jev) {
            try await plan(for: step.observation.snapshot, progress: progress, withHints: hinted)
        }
        guard case let .act(action) = decide(on: plan, progress: context.progress) else { return .finished(outcome) }
        return try await act(action, after: step, context: &context)
    }

    /// Takes `action` on the confirming reading, or plans again when its target is no longer where it was planned.
    func act(_ action: AgentAction, after step: PlannedStep, context: inout AgentLoopContext) async throws -> AgentLoopState {
        let target = if step.overlapped {
            confirmed(action, planned: step.observation.snapshot, fresh: step.fresh.snapshot, progress: context.progress)
        } else {
            try await context.timing.add(to: \.read) { [progress = context.progress] in
                try await isStillCurrent(step.observation.snapshot, progress: progress)
            } ? action : nil
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
        let (performed, disappeared) = try await context.timing.add(to: \.act) { try await perform(target, on: step.fresh.snapshot) }
        acted(performed, disappeared: disappeared, on: step.fresh.snapshot, context: &context)
        return .observing(pending: nil)
    }

    /// Records the action that ended a step and reports where the step's time went.
    private func acted(_ action: AgentAction, disappeared: [String], on snapshot: UISnapshot, context: inout AgentLoopContext) {
        let (step, timing) = context.acted(action, disappeared: disappeared, on: snapshot)
        report(.timed(step: step, timing: timing))
    }
}

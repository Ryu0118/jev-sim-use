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
            try await context.timed(\.read) { try await observeAfterAction(on: actedOn, settled: settled) }
        }
        if let outcome = context.progress.record(observation, stallLimit: configuration.stallLimit) {
            return .finished(outcome)
        }
        if let typing = context.typing {
            context.typing = nil
            try await checkLanded(typing, in: observation.snapshot, context: &context)
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
            plan = try await context.timed(\.jev) { try await self.plan(for: observation.snapshot, progress: progress) }
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
            context.watch.acting(action, on: observation.snapshot)
            let disappeared: [String]
            do {
                disappeared = try await context.timed(\.act) { try await driver.tapWhereShown(target, on: observation.snapshot) }
            } catch {
                confirmation?.cancel()
                throw error
            }
            context.watch.acting(nil, on: nil)
            let late = try await context.timed(\.read) { try await Self.value(of: confirmation) }
            acted(action, disappeared: disappeared + (late?.disappearedApps ?? []), on: observation.snapshot, context: &context)
            return .observing(pending: nil)
        }
        // Only the wait after Jev answered counts: the rest of the confirming read ran under Jev's request.
        let fresh = try await context.timed(\.read) { try await Self.value(of: confirmation) } ?? observation
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
        if shouldRetryWithHints(decision, on: step.observation.snapshot) {
            report(.retryingWithHints(step: context.progress.nextStep))
            let progress = context.progress
            let hinted = try await context.timed(\.jev) {
                try await plan(for: step.observation.snapshot, progress: progress, withHints: true)
            }
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
        guard context.staleReplans < Self.staleReplanLimit, outcome.isHandOver else { return .finished(outcome) }
        context.watch.extend(by: configuration.handOverWait)
        let (again, changed) = try await context.timed(\.handOver) { try await reading(changedFrom: step.fresh.snapshot) }
        // An app that disappeared while the wait read is a crash, whether or not the screen moved on.
        if !again.disappearedApps.isEmpty, let crash = context.progress.record(again, stallLimit: configuration.stallLimit) {
            return .finished(crash)
        }
        guard changed else { return .finished(outcome) }
        context.staleReplans += 1
        return .observing(pending: again)
    }

    /// Takes `action` on the confirming reading, or plans again when its target is no longer where it was planned.
    func act(_ action: AgentAction, after step: PlannedStep, context: inout AgentLoopContext) async throws -> AgentLoopState {
        let target = if step.overlapped {
            confirmed(action, planned: step.observation.snapshot, fresh: step.fresh.snapshot, progress: context.progress)
        } else {
            try await context.timed(\.read) { [progress = context.progress] in
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
        context.watch.acting(target, on: step.fresh.snapshot)
        if target == .wait {
            context.watch.extend(by: configuration.waitDuration)
        }
        let (performed, disappeared) = try await context.timed(\.act) { try await perform(target, on: step.fresh.snapshot) }
        context.watch.acting(nil, on: nil)
        acted(performed, disappeared: disappeared, on: step.fresh.snapshot, context: &context)
        return .observing(pending: nil)
    }

    /// The confirming reading, cancelled with the caller: a cut-off cycle must not leave it running.
    static func value(of confirmation: Task<ScreenObservation, any Error>?) async throws -> ScreenObservation? {
        guard let confirmation else { return nil }
        return try await withTaskCancellationHandler {
            try await confirmation.value
        } onCancel: {
            confirmation.cancel()
        }
    }

    /// Checks that typed text shows in its field on the reading after it (iOS only: Android field values were never
    /// observed). sim-use reports a paste as done even when nothing arrived: on one simulator neither the pasteboard
    /// nor key events reached the app, and an event was saved without its title while the run claimed success. When
    /// the simulator's pasteboard does not hold the text the device is at fault and the run stops; otherwise the step
    /// is marked so Jev can retry, and a second miss in a row stops the run.
    private func checkLanded(_ typing: (field: Int, text: InputText), in fresh: UISnapshot, context: inout AgentLoopContext) async throws {
        guard let before = context.actedOn, before.platform == SimUseContract.Platform.ios,
              before.typedText(typing.text.value, landedIn: typing.field, after: fresh) == false
        else { return }
        if await driver.pasteboardHolds(typing.text.value) == false {
            throw SimUseError.pasteboardUnavailable
        }
        if context.progress.history.dropLast().last?.textLanded == false {
            throw SimUseError.typedTextNotLanded
        }
        context.progress.markTextNotLanded()
    }

    /// Records the action that ended a step and reports where the step's time went.
    private func acted(_ action: AgentAction, disappeared: [String], on snapshot: UISnapshot, context: inout AgentLoopContext) {
        let (step, timing) = context.acted(action, disappeared: disappeared, on: snapshot)
        report(.timed(step: step, timing: timing))
    }
}

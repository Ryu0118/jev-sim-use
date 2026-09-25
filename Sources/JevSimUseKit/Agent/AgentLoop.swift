/// Observe → plan → act, until Jev judges the goal reached or a stop condition hits.
///
/// sim-use has no launch verb, so a run starts from whatever is on screen.
package struct AgentLoop: Sendable {
    let driver: any DeviceDriving
    let planner: any StepPlanning
    let configuration: AgentConfiguration
    let report: @Sendable (AgentEvent) -> Void

    /// Creates a loop. `report` receives progress events as they happen.
    package init(
        driver: any DeviceDriving,
        planner: any StepPlanning,
        configuration: AgentConfiguration,
        report: @escaping @Sendable (AgentEvent) -> Void = { _ in },
    ) {
        self.driver = driver
        self.planner = planner
        self.configuration = configuration
        self.report = report
    }

    /// Runs until an outcome is reached. Throws only for sim-use or Jev failures.
    ///
    /// `history` continues an earlier run: Jev sees it and step numbers carry on, but `maxSteps` and loop detection
    /// start fresh, so a run that stopped at the step limit or stalled can make progress when resumed.
    package func run(continuing history: [HistoryEntry] = []) async throws -> AgentRunResult {
        var progress = AgentProgress(history: history)
        var actedOn: UISnapshot?
        var pending: ScreenObservation?
        var staleReplans = 0
        var disagreements = 0
        while true {
            try Task.checkCancellation()
            let overlapped = disagreements < Self.disagreementLimit
            // Falling back discards a pending reading: it was one of the readings that kept disagreeing.
            let observation = if let pending, overlapped {
                pending
            } else {
                try await observeAfterAction(on: actedOn, settled: !overlapped)
            }
            pending = nil
            if let outcome = progress.record(observation, stallLimit: configuration.stallLimit) {
                return AgentRunResult(outcome: outcome, history: progress.history)
            }
            // The first reading after an action may be mid-transition, so a second one runs while Jev plans and
            // decides whether the plan still applies (see `confirmed`). It replaced reading until two readings agreed
            // before planning, which cost a whole read on every step.
            let confirmation = overlapped ? Task { try await driver.observe() } : nil
            let plan: StepPlan
            do {
                plan = try await self.plan(for: observation.snapshot, progress: progress)
            } catch {
                confirmation?.cancel()
                throw error
            }
            let fresh = try await confirmation?.value ?? observation
            if overlapped, !fresh.disappearedApps.isEmpty,
               let outcome = progress.record(fresh, stallLimit: configuration.stallLimit)
            {
                return AgentRunResult(outcome: outcome, history: progress.history)
            }
            let settled = fresh.snapshot.layout == observation.snapshot.layout
            if configuration.allowedOperations.allows(.device(.revealContentBelow)), let scan = ScanFirst.override(
                plan, on: observation.snapshot, goal: configuration.goal, notes: configuration.notes,
                alreadyScanned: progress.hasScannedCurrentTitle, tried: progress.ineffectiveActions,
            ), progress.steps < configuration.maxSteps {
                guard settled else {
                    disagreements += 1
                    pending = fresh
                    continue
                }
                report(.scanning(step: progress.nextStep))
                progress.markScanned()
                let disappeared = try await execute(scan, on: fresh.snapshot)
                progress.recordAction(scan, disappeared: disappeared)
                actedOn = fresh.snapshot
                disagreements = 0
                continue
            }
            var decision = decide(on: plan, progress: progress)
            if shouldRetryWithHints(decision, on: observation.snapshot) {
                report(.retryingWithHints(step: progress.nextStep))
                let hinted = try await self.plan(for: observation.snapshot, progress: progress, withHints: true)
                decision = decide(on: hinted, progress: progress)
            }
            switch decision {
            case let .stop(outcome):
                // DONE on a screen still changing could claim a goal the settled screen does not show.
                guard settled else {
                    disagreements += 1
                    pending = fresh
                    continue
                }
                // A saved item can reach a list a second after the screen changed: Jev, planning on the list without
                // it, scrolled at 0.40 and stopped. Before handing over, keep reading briefly and plan again if the
                // screen moved on (jev-ultrafast checks freshness the same way), a bounded number of times per step.
                if staleReplans < Self.staleReplanLimit, outcome.isHandOver,
                   let again = try await reading(changedFrom: fresh.snapshot)
                {
                    staleReplans += 1
                    pending = again
                    continue
                }
                return AgentRunResult(outcome: outcome, history: progress.history)
            case let .act(action):
                let target = if overlapped {
                    confirmed(action, planned: observation.snapshot, fresh: fresh.snapshot, progress: progress)
                } else {
                    try await isStillCurrent(observation.snapshot, progress: progress) ? action : nil
                }
                guard let target else {
                    disagreements += overlapped ? 1 : 0
                    pending = overlapped ? fresh : nil
                    actedOn = nil
                    continue
                }
                if !settled, fresh.snapshot.identity != observation.snapshot.identity,
                   let outcome = progress.record(fresh, stallLimit: configuration.stallLimit)
                {
                    return AgentRunResult(outcome: outcome, history: progress.history)
                }
                let (performed, disappeared) = try await perform(target, on: fresh.snapshot)
                progress.recordAction(performed, disappeared: disappeared)
                actedOn = fresh.snapshot
                staleReplans = 0
                disagreements = 0
            }
        }
    }
}

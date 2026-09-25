extension AgentLoop {
    func plan(for snapshot: UISnapshot, progress: AgentProgress, withHints: Bool = false) async throws -> StepPlan {
        var request = PlanRequest(
            goal: configuration.goal,
            snapshot: snapshot,
            menu: ActionCatalog.menu(
                for: snapshot, texts: configuration.texts, excluding: progress.ineffectiveActions,
                explored: progress.exploredElements, allowed: configuration.allowedOperations,
            ),
            history: progress.history,
            notes: configuration.notes,
        )
        request.includesHints = withHints
        let plan = try await planner.plan(request)
        report(.planned(step: progress.nextStep, plan: plan))
        return plan
    }

    /// Whether a step that is about to hand over should be asked once more with the screen's accessibility hints.
    /// Hints are left out of the first request to keep it small; they help most when labels look alike and Jev is
    /// torn, which is exactly when it would stop (TypeSafe's escalate-on-uncertainty pattern).
    func shouldRetryWithHints(_ decision: StepDecision, on snapshot: UISnapshot) -> Bool {
        guard case let .stop(outcome) = decision, (snapshot.entries ?? []).contains(where: { $0.hint != nil }) else {
            return false
        }
        return switch outcome {
        case .escalated, .noActionFits: true
        default: false
        }
    }

    /// DONE is Jev's claim, not proof, so exit 0 needs it to clear a bar; below it the run stops as probably done.
    func decide(on plan: StepPlan, progress: AgentProgress) -> StepDecision {
        if plan.action == .done {
            return plan.support >= ActionPolicy.doneMinimum
                ? .stop(.goalReached(steps: progress.steps))
                : .stop(.goalProbablyReached(steps: progress.steps, probability: plan.support))
        }
        if progress.steps >= configuration.maxSteps {
            return .stop(.stepLimitReached(steps: progress.steps))
        }
        let step = progress.nextStep
        // Code does not explore on Jev's behalf: scrolling or going back when Jev was unsure moved away from the right
        // screen as often as it found anything. Nothing fitting, or a repeat of an action that did nothing on this
        // screen, hands over like low support does.
        if plan.action == .noneApplies || progress.ineffectiveActions.contains(plan.action.optionName) {
            return .stop(.noActionFits(step: step))
        }
        if plan.support < configuration.actionPolicy.requiredSupport(for: plan.action) {
            return .stop(.escalated(step: step, action: plan.action, confidence: plan.support))
        }
        if plan.support < ActionPolicy.confidentSupport {
            report(.lowConfidence(step: step, confidence: plan.support))
        }
        return .act(plan.action)
    }

    func execute(_ action: AgentAction, on snapshot: UISnapshot) async throws -> [String] {
        switch action {
        case let .tap(alias, _, _): try await driver.tap(alias: alias, on: snapshot)
        case let .gesture(gesture, alias, _, _): try await driver.perform(gesture, alias: alias, on: snapshot)
        // iOS offers go_back only where a back button shows; tapping it is what the edge swipe stands for, and the
        // swipe was swallowed on a detail screen whose map took the drag.
        case .device(.goBack) where snapshot.platform == SimUseContract.Platform.ios:
            if let back = snapshot.entries?.first(where: { $0.uniqueId == ActionCatalog.iOSBackButtonIdentifier }) {
                try await driver.tap(alias: back.aliases.alias, on: snapshot)
            } else {
                try await driver.perform(.goBack, platform: snapshot.platform)
            }
        case let .device(deviceAction): try await driver.perform(deviceAction, platform: snapshot.platform)
        case let .enterText(field, _, text):
            try await driver.tap(alias: field, on: snapshot) + driver.paste(text.value)
        case .done, .noneApplies: []
        }
    }

    /// How many times one step is planned again because the screen changed while Jev decided to stop.
    static let staleReplanLimit = 2

    /// How long a live run keeps reading after an action that left the screen as it was.
    static let unchangedWait: Duration = .seconds(2)

    /// Reads the screen after acting on `previous`. Saving a memo kept its form on screen for over a second while the
    /// save went through, and Jev, planning on the form, tapped the screen that replaced it. So an unchanged screen is
    /// read again, back to back (one `ui` read takes about 0.4 s, so no sleep is needed between them), until it
    /// changes or `unchangedWait` passes. `settled` reads until two readings agree each time, for when overlapped
    /// confirmation keeps disagreeing.
    func observeAfterAction(on previous: UISnapshot?, settled: Bool) async throws -> ScreenObservation {
        let read = { settled ? try await observeSettled() : try await driver.observe() }
        var observation = try await read()
        guard let previous else { return observation }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: configuration.unchangedWait)
        while clock.now < deadline, observation.snapshot.identity == previous.identity {
            let next = try await read()
            observation = ScreenObservation(
                snapshot: next.snapshot, disappearedApps: observation.disappearedApps + next.disappearedApps,
            )
        }
        return observation
    }

    /// A reading whose layout differs from `snapshot`'s, taken within `unchangedWait`, or `nil` if none came. A saved
    /// memo reached its list over a second after the editor closed, after the step had already been planned twice.
    func reading(changedFrom snapshot: UISnapshot) async throws -> ScreenObservation? {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: configuration.unchangedWait)
        repeat {
            let reading = try await driver.observe()
            if reading.snapshot.layout != snapshot.layout {
                return reading
            }
        } while clock.now < deadline
        return nil
    }

    /// How many times one step is planned again because the confirming reading disagreed with the planned one, before
    /// the loop falls back to reading until two readings agree and planning without a confirming reading.
    static let disagreementLimit = 2

    /// The action to take on `fresh`, the reading taken while Jev planned on `planned`, or `nil` to plan again on
    /// `fresh`. A reading taken mid-transition showed the old screen, and one taken while a scroll still coasted had
    /// stale frames; either way sim-use's cached alias would hit whatever had moved under it. An identical reading
    /// keeps the plan. When the last action had not shown its effect yet, any change may be that effect arriving, so
    /// the plan is for a screen that is gone. Otherwise the same layout keeps the plan too, and an action on an element
    /// still goes ahead, re-aliased, when that element sits unchanged where it was planned (a clock or spinner
    /// elsewhere does not matter).
    func confirmed(_ action: AgentAction, planned: UISnapshot, fresh: UISnapshot, progress: AgentProgress) -> AgentAction? {
        if fresh.outline == planned.outline {
            return action
        }
        guard progress.history.last?.screenChanged != false else { return nil }
        return fresh.layout == planned.layout ? action : action.retargeted(from: planned, to: fresh)
    }

    /// Whether `planned` is still the screen, read just before acting on it, when planning without a confirming
    /// reading. Only an action whose effect has not shown yet can change the screen while Jev decides, so the check
    /// runs only then and costs no read otherwise.
    func isStillCurrent(_ planned: UISnapshot, progress: AgentProgress) async throws -> Bool {
        guard progress.history.last?.screenChanged == false else { return true }
        return try await driver.observe().snapshot.identity == planned.identity
    }

    /// Extra readings allowed while the screen is still changing.
    static let settleReads = 2

    /// Reads the screen until two readings agree, frames included. A reading taken mid-transition showed the old
    /// screen, and one taken while a scroll still coasted had stale frames; either way sim-use's cached alias then hit
    /// whatever had moved under it.
    func observeSettled() async throws -> ScreenObservation {
        var reading = try await driver.observe()
        var disappeared = reading.disappearedApps
        for _ in 0 ..< Self.settleReads {
            let next = try await driver.observe()
            disappeared += next.disappearedApps
            let settled = next.snapshot.outline == reading.snapshot.outline
            reading = next
            if settled {
                break
            }
        }
        return ScreenObservation(snapshot: reading.snapshot, disappearedApps: disappeared)
    }
}

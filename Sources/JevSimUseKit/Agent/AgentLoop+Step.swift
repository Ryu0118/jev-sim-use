extension AgentLoop {
    func plan(for snapshot: UISnapshot, progress: AgentProgress) async throws -> StepPlan {
        let request = PlanRequest(
            goal: configuration.goal,
            snapshot: snapshot,
            menu: ActionCatalog.menu(
                for: snapshot, texts: configuration.texts, excluding: progress.ineffectiveActions,
                explored: progress.exploredElements,
            ),
            history: progress.history,
            notes: configuration.notes,
        )
        let plan = try await planner.plan(request)
        report(.planned(step: progress.nextStep, plan: plan))
        return plan
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
        case let .device(deviceAction): try await driver.perform(deviceAction, platform: snapshot.platform)
        case let .enterText(field, _, text):
            try await driver.tap(alias: field, on: snapshot) + driver.paste(text.value)
        case .done, .noneApplies: []
        }
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

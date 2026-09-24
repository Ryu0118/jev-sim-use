extension AgentLoop {
    func plan(for snapshot: UISnapshot, progress: AgentProgress) async throws -> StepPlan {
        let request = PlanRequest(
            goal: configuration.goal,
            snapshot: snapshot,
            actions: ActionCatalog.actions(
                for: snapshot, texts: configuration.texts, excluding: progress.ineffectiveActions,
            ),
            history: progress.history,
            notes: configuration.notes,
            gestureTargets: ActionCatalog.gestureTargets(for: snapshot),
        )
        let plan = try await planner.plan(request)
        report(.planned(step: progress.nextStep, plan: plan))
        return plan
    }

    /// Checks completion before the step limit, so a goal reached by the last allowed action counts.
    /// Only an `.auto` judgement counts as reached, because the exit status claims success.
    func decide(on plan: StepPlan, progress: AgentProgress) -> StepDecision {
        let done = configuration.goalPolicy.decide(plan.goalReached)
        if done.answer == true, done.decision == .auto {
            return .stop(.goalReached(steps: progress.steps))
        }
        if progress.steps >= configuration.maxSteps {
            return .stop(.stepLimitReached(steps: progress.steps))
        }
        if plan.action == .noneApplies, done.answer == true {
            return .stop(.goalProbablyReached(steps: progress.steps, probability: plan.goalReached.value))
        }
        let step = progress.nextStep
        // A gesture is composed from answers, not picked from filtered options, so a repeat is caught here.
        if plan.action == .noneApplies || progress.ineffectiveActions.contains(plan.action.optionName) {
            guard let action = Exploration.next(excluding: progress.ineffectiveActions) else {
                return .stop(.noActionFits(step: step))
            }
            report(.exploring(step: step, action: action))
            return .act(action)
        }
        if plan.support < configuration.actionPolicy.requiredSupport(for: plan.action) {
            // An unsure reversible pick often means the target is off screen. Exploring costs one step; handing over
            // costs the supervisor a turn. Irreversible picks still hand over at once.
            if plan.action.risk != .irreversible, let action = Exploration.next(excluding: progress.ineffectiveActions) {
                report(.exploring(step: step, action: action))
                return .act(action)
            }
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
        case let .paste(_, text): try await driver.paste(text.value)
        case .noneApplies: []
        }
    }
}

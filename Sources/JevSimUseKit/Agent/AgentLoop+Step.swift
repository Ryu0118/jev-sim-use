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
        let step = progress.nextStep
        if plan.action == .noneApplies {
            guard let action = Exploration.next(excluding: progress.ineffectiveActions) else {
                return .stop(.noActionFits(step: step))
            }
            report(.exploring(step: step, action: action))
            return .act(action)
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
        case let .tap(alias, _, _):
            if let frame = Self.switchFrame(alias: alias, in: snapshot) {
                try await driver.tapSwitch(in: frame)
            } else {
                try await driver.tap(alias: alias)
            }
        case let .device(deviceAction): try await driver.perform(deviceAction, platform: snapshot.platform)
        case let .paste(_, text): try await driver.paste(text)
        case .noneApplies: []
        }
    }

    /// The frame to tap for an iOS toggle, which ignores sim-use's default instant tap at the row centre.
    static func switchFrame(alias: Int, in snapshot: UISnapshot) -> ElementFrame? {
        guard snapshot.platform == "ios",
              let entry = snapshot.entries?.first(where: { $0.aliases.alias == alias }), entry.isToggle
        else { return nil }
        return entry.frame
    }
}

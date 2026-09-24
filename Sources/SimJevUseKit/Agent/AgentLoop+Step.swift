extension AgentLoop {
    func plan(for snapshot: UISnapshot, progress: AgentProgress) async throws -> StepPlan {
        let request = PlanRequest(
            goal: configuration.goal,
            snapshot: snapshot,
            actions: ActionCatalog.actions(for: snapshot, texts: configuration.texts),
            history: progress.history,
        )
        let plan = try await planner.plan(request)
        report(.planned(step: progress.steps + 1, plan: plan))
        return plan
    }

    /// Checks completion before the step limit, so a goal reached by the last allowed action counts.
    func verdict(on plan: StepPlan, progress: AgentProgress) -> AgentOutcome? {
        let done = configuration.policy.decide(plan.goalReached)
        if done.answer == true, done.decision != .escalate {
            return .goalReached(steps: progress.steps)
        }
        if progress.steps >= configuration.maxSteps {
            return .stepLimitReached(steps: progress.steps)
        }
        let step = progress.steps + 1
        if plan.confidence < configuration.policy.escalateBelow {
            return .escalated(step: step, action: plan.action, confidence: plan.confidence)
        }
        if plan.confidence < configuration.policy.autoAtOrAbove {
            report(.lowConfidence(step: step, confidence: plan.confidence))
        }
        return nil
    }

    func execute(_ action: AgentAction, platform: String) async throws -> [String] {
        switch action {
        case let .tap(alias, _, _): try await driver.tap(alias: alias)
        case let .device(deviceAction): try await driver.perform(deviceAction, platform: platform)
        case let .paste(_, text): try await driver.paste(text)
        }
    }
}

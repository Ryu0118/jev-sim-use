import Jev
@testable import SimJevUseKit
import Synchronization

/// Returns plans in order, repeating the last one.
final class FakePlanner: StepPlanning {
    private let plans: [StepPlan]
    private let index = Mutex(0)

    init(_ plans: [StepPlan]) {
        self.plans = plans
    }

    func plan(_: PlanRequest) async throws -> StepPlan {
        index.withLock { index in
            defer { index += 1 }
            return plans[min(index, plans.count - 1)]
        }
    }
}

extension StepPlan {
    static func tapNext(confidence: Double = 0.9, goal: Double = 0.05) -> StepPlan {
        StepPlan(
            goalReached: Probability(clamping: goal),
            action: .tap(alias: 1, role: "Button", label: "Next"),
            confidence: confidence,
            costUSD: 0,
        )
    }
}

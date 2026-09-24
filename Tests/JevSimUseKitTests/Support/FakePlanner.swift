import Jev
@testable import JevSimUseKit
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
    static func tapNext(confidence: Double = 0.9, finishes: Double = 0.05) -> StepPlan {
        StepPlan(
            action: .tap(alias: 1, role: "Button", label: "Next"),
            confidence: confidence,
            finishes: Probability(clamping: finishes),
            costUSD: 0,
        )
    }

    static func done(confidence: Double = 0.9) -> StepPlan {
        StepPlan(action: .done, confidence: confidence, costUSD: 0)
    }

    static func blocked() -> StepPlan {
        StepPlan(action: .noneApplies, confidence: 0.9, costUSD: 0)
    }
}

@testable import JevSimUseKit
import Synchronization

/// Records the screen each plan was made on and always hands over.
final class RecordingPlanner: StepPlanning {
    private let seen = Mutex<[String]>([])

    var outlines: [String] {
        seen.withLock { $0 }
    }

    func plan(_ request: PlanRequest) async throws -> StepPlan {
        seen.withLock { $0.append(request.snapshot.outline) }
        return .blocked()
    }
}

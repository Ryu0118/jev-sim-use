import Foundation

/// How one `run` or `session resume` ended.
package struct SessionRun: Codable, Sendable, Hashable {
    /// When the run ended.
    package let endedAt: Date
    /// Actions this run took.
    package let steps: Int
    /// Whether the goal was reached.
    package let succeeded: Bool
    /// The stop reason, as `AgentOutcome` describes it.
    package let outcome: String

    package init(endedAt: Date, steps: Int, succeeded: Bool, outcome: String) {
        self.endedAt = endedAt
        self.steps = steps
        self.succeeded = succeeded
        self.outcome = outcome
    }
}

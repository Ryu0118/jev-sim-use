import Foundation

/// How one `run` or `session resume` stopped short of the goal. Runs that reach it delete their session.
package struct SessionRun: Codable, Sendable, Hashable {
    /// When the run ended.
    package let endedAt: Date
    /// Actions this run took.
    package let steps: Int
    /// The stop reason, as `AgentOutcome` describes it.
    package let outcome: String

    package init(endedAt: Date, steps: Int, outcome: String) {
        self.endedAt = endedAt
        self.steps = steps
        self.outcome = outcome
    }
}

/// How a run ended, and the session it belongs to.
package struct RunGoalOutcome: Sendable, Hashable {
    /// The session to inspect, `tell`, or `resume` next.
    package var sessionID: String
    /// Why the run stopped.
    package var outcome: AgentOutcome
}

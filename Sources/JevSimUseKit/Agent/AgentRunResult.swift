/// How a run ended, and every action taken so far, including the history the run continued from.
package struct AgentRunResult: Sendable, Hashable {
    /// Why the run stopped.
    package var outcome: AgentOutcome
    /// Earlier history followed by this run's actions.
    package var history: [HistoryEntry]
    /// Where this run's time went, the last step included, which took no action and so has no history entry.
    package var timing = StepTiming()
}

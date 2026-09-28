/// The warnings a run prints for daemon replacements.
package final class RecoveryWarnings: Sendable {
    package init() {}

    /// The warning for `recovery`.
    package func warning(for recovery: DaemonRecovery) -> String? {
        recovery.description
    }
}

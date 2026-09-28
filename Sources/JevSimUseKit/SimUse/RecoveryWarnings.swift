import Synchronization

/// The warnings a run prints for daemon replacements: the first one only. A daemon that ignored `daemon stop` was
/// replaced on every read, and the same warning printed three times in a row.
package final class RecoveryWarnings: Sendable {
    private let warned = Mutex(false)

    package init() {}

    /// The warning for `recovery` when it is the run's first replacement, else `nil`.
    package func warning(for recovery: DaemonRecovery) -> String? {
        let first = warned.withLock { warned in
            defer { warned = true }
            return !warned
        }
        return first ? recovery.description + " Later replacements in this run are not repeated." : nil
    }
}

import Synchronization

/// Bounds iOS screen reads, so a hung sim-use daemon costs a run seconds instead of minutes.
///
/// A healthy `ui` read took 0.45-0.67 s through the daemon or outside it; a hung daemon made reads take about 10 s
/// (0.7 s outside it), a fresh daemon hung again within a minute, and a daemon process that stopped answering kept a
/// read blocked for minutes. A read past `deadline` is cancelled, the device's daemon is stopped, and the screen is
/// read outside it; the next read starts a fresh daemon. That happens at most `limit` times per run, each reported.
/// After that, reads are waited out up to `cap`, which a naturally hung daemon stays well under: failing there would
/// end runs that finish today, only slowly. Shared by every read of one client, including a confirming read that runs
/// while Jev plans.
package final class SimUseDaemonWatchdog: Sendable {
    /// About five times the slowest healthy read, and well under a hung one.
    package static let readDeadline: Duration = .seconds(3)
    /// Replacements allowed per run.
    package static let recoveryLimit = 2
    /// Three times the slowest naturally hung read.
    package static let readCap: Duration = .seconds(30)

    /// How long a read through the daemon may take.
    let deadline: Duration
    /// How long a read through the daemon may take once no replacement is left.
    let cap: Duration
    private let limit: Int
    private let report: @Sendable (DaemonRecovery) -> Void
    private let state = Mutex(State())

    private struct State {
        var recoveries = 0
        var lastApp: String?
    }

    /// Creates a watchdog that passes each replacement to `report`.
    package init(
        deadline: Duration = readDeadline,
        cap: Duration = readCap,
        limit: Int = recoveryLimit,
        report: @escaping @Sendable (DaemonRecovery) -> Void = { _ in },
    ) {
        self.deadline = deadline
        self.cap = cap
        self.limit = limit
        self.report = report
    }

    /// Remembers the app a reading showed, to compare with the first reading after a replacement.
    func noteReading(of app: String?) {
        state.withLock { $0.lastApp = app }
    }

    /// Whether a replacement is left in this run.
    var canRecover: Bool {
        state.withLock { $0.recoveries < limit }
    }

    /// Takes one replacement from the run's allowance and returns the app on screen before the hang, or `nil` when
    /// the allowance is used up.
    func claimRecovery() -> (lastApp: String?, left: Int)? {
        state.withLock { state in
            guard state.recoveries < limit else { return nil }
            state.recoveries += 1
            return (state.lastApp, limit - state.recoveries)
        }
    }

    /// Reports a finished replacement.
    func recovered(_ recovery: DaemonRecovery) {
        report(recovery)
    }
}

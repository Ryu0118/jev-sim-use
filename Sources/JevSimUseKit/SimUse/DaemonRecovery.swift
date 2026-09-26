/// One replacement of a hung sim-use daemon by `SimUseDaemonWatchdog`.
package struct DaemonRecovery: Sendable, Hashable, CustomStringConvertible {
    /// The device whose daemon hung.
    package let deviceID: String
    /// How long the read waited before it was given up.
    package let waited: Duration
    /// Whether `daemon stop` reported the daemon gone. When it did not, the next read may hang again.
    package let daemonStopped: Bool
    /// Replacements still allowed in this run.
    package let left: Int

    /// A warning that names the likely cause and the commands that fix it by hand.
    package var description: String {
        let seconds = (waited / .seconds(1)).formatted()
        let daemon = daemonStopped ? "the sim-use daemon for this device was stopped" : "the sim-use daemon could not be stopped"
        return "a sim-use screen read had no answer after \(seconds) s, so \(daemon) and the screen was read without it "
            + "(\(left) more replacement(s) this run). If reads stay slow, check `jev-sim-use exec daemon status` and run "
            + "`jev-sim-use exec daemon stop --device \(deviceID)`."
    }
}

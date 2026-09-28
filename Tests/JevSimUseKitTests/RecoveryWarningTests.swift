@testable import JevSimUseKit
import Testing

/// A daemon that ignored `daemon stop` was replaced on every read, and the same warning printed three times in a row.
@Suite("A run warns about daemon replacements once")
struct RecoveryWarningTests {
    @Test("gives the first replacement's warning and none for later ones in the same run")
    func warnsOnce() {
        let warnings = RecoveryWarnings()
        let recovery = DaemonRecovery(deviceID: "D", waited: .seconds(10), daemonStopped: false)
        let first = warnings.warning(for: recovery)
        #expect(first?.contains("daemon") == true)
        #expect(warnings.warning(for: recovery) == nil)
        #expect(warnings.warning(for: DaemonRecovery(deviceID: "D", waited: .seconds(3), daemonStopped: true)) == nil)
    }
}

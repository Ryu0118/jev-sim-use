/// A verified sim-use installation with a pinned device.
package struct SimUseConnection: Sendable {
    /// Drives the pinned device.
    package let client: SimUseClient
    /// The installed sim-use version.
    package let version: SemanticVersion

    /// Set when the installed sim-use is newer than the version this tool was verified against.
    package var versionWarning: String? {
        guard version > SimUseBootstrap.testedVersion else { return nil }
        return "sim-use \(version) is newer than the tested \(SimUseBootstrap.testedVersion). "
            + "If something fails, check `jev-sim-use exec --version` and run `mise run contract-test`."
    }
}

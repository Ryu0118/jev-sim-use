/// Everything that can go wrong locating or driving `sim-use`.
public enum SimUseError: Error, Sendable, Equatable {
    /// `sim-use` is not on `PATH`.
    case notInstalled(searchedPath: String)
    /// `sim-use --version` printed nothing that parses as a version.
    case unreadableVersion(output: String)
    /// The installed `sim-use` is older than this tool supports.
    case outdated(found: SemanticVersion, minimum: SemanticVersion)
    /// No usable device is booted or connected.
    case noDevice
    /// More than one usable device; the caller must pick one with `--device`.
    case multipleDevices([SimUseDevice])
    /// `sim-use` reported a failure.
    case commandFailed(arguments: [String], message: String, hint: String?)
    /// `sim-use` exited without an output this tool understands.
    case malformedOutput(arguments: [String], detail: String)
}

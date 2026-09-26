/// Everything that can go wrong locating or driving `sim-use`.
package enum SimUseError: Error, Sendable, Equatable {
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
    /// Text entry needs a connected hardware keyboard: without one iOS drops sim-use's paste.
    case hardwareKeyboardRequired
    /// `sim-use` exited without an output this tool understands.
    case malformedOutput(arguments: [String], detail: String)
    /// A screen read on `deviceID` still had no answer after `seconds`, after the run's daemon replacements were used up.
    case readTimedOut(deviceID: String, seconds: Double)
    /// A tap scrolled its element into reach but did not find it afterwards, so only `scroll` happened. The agent
    /// loop records the scroll instead of the tap and plans on the moved screen.
    case targetNotRevealed(scroll: SimUseDeviceAction, disappearedApps: [String])
}

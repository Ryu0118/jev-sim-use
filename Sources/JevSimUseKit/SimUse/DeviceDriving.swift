/// Drives one pinned device. A seam so the agent loop can be tested without sim-use.
///
/// Every call returns the bundle ids of apps sim-use saw disappear, because sim-use
/// reports liveness events on whichever command runs next.
package protocol DeviceDriving: Sendable {
    /// Reads the current screen.
    func observe() async throws -> ScreenObservation
    /// Taps the element with alias `@alias` from the latest observation.
    func tap(alias: Int) async throws -> [String]
    /// Flips the iOS switch in a row with `frame`: a held tap on the switch itself, since a row-centre tap is ignored.
    func tapSwitch(in frame: ElementFrame) async throws -> [String]
    /// Performs a device-level action on `platform`.
    func perform(_ action: SimUseDeviceAction, platform: String) async throws -> [String]
    /// Pastes `text` into the focused field. Paste handles Unicode on iOS, unlike `type`.
    func paste(_ text: String) async throws -> [String]
}

/// One `sim-use ui` reading.
package struct ScreenObservation: Sendable, Hashable {
    /// The decoded describe-ui payload.
    package var snapshot: UISnapshot
    /// Apps sim-use saw disappear since the previous command.
    package var disappearedApps: [String]

    /// Creates an observation.
    package init(snapshot: UISnapshot, disappearedApps: [String]) {
        self.snapshot = snapshot
        self.disappearedApps = disappearedApps
    }
}

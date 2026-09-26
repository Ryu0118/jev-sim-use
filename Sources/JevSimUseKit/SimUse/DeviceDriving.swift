/// Drives one pinned device. A seam so the agent loop can be tested without sim-use.
///
/// Every call returns the bundle ids of apps sim-use saw disappear, because sim-use
/// reports liveness events on whichever command runs next.
package protocol DeviceDriving: Sendable {
    /// Reads the current screen.
    func observe() async throws -> ScreenObservation
    /// Taps the element with alias `@alias` in `snapshot`, the latest observation, in whatever way flips or presses it.
    func tap(alias: Int, on snapshot: UISnapshot) async throws -> [String]
    /// Taps `entry` where `snapshot` shows it, by coordinates rather than by alias, so a screen read running at the
    /// same time cannot change which element the tap resolves to.
    func tapWhereShown(_ entry: UIEntry, on snapshot: UISnapshot) async throws -> [String]
    /// Performs `gesture` on the element with alias `@alias` in `snapshot`, the latest observation.
    func perform(_ gesture: ElementGesture, alias: Int, on snapshot: UISnapshot) async throws -> [String]
    /// Performs a device-level action on `platform`.
    func perform(_ action: SimUseDeviceAction, platform: String) async throws -> [String]
    /// Pastes `text` into the focused field, in place of its content when `replacing`. Paste handles Unicode on iOS,
    /// unlike `type`.
    func paste(_ text: String, replacing: Bool) async throws -> [String]
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

package extension DeviceDriving {
    /// Taps by alias; drivers without an alias cache have nothing a concurrent read could change.
    func tapWhereShown(_ entry: UIEntry, on snapshot: UISnapshot) async throws -> [String] {
        try await tap(alias: entry.aliases.alias, on: snapshot)
    }
}

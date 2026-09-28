/// Tells when the device's screen image changed and when it stopped changing, without reading the screen through
/// sim-use. Only when to read comes from it; what changed is still judged by reading the screen.
package protocol ScreenChangeWatching: Sendable {
    /// Waits until the image changes after `instant` (a change already seen counts), or `deadline` passes; whether it
    /// changed. Throws only when cancelled.
    func waitForChange(after instant: ContinuousClock.Instant, until deadline: ContinuousClock.Instant) async throws -> Bool

    /// Waits until the image has not changed for `quiet`, or `deadline` passes; whether it went still. Throws only when
    /// cancelled.
    func waitUntilStill(for quiet: Duration, until deadline: ContinuousClock.Instant) async throws -> Bool
}

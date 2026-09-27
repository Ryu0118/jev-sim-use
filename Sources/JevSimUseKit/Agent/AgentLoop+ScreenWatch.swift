/// The loop's waits with a screen-change watcher: instead of reading back to back, wait for the image to change and
/// settle, then read once. What changed is still judged by the reading, so a watcher that misses a change only makes
/// the wait end at its deadline.
extension AgentLoop {
    /// `base`, or as long as `reads` readings take at the device's current pace when that is longer: under load the
    /// app renders as slowly as sim-use reads, and the polling wait gave the effect that many reads.
    func waitSpan(_ base: Duration, reads: Int) -> Duration {
        max(base, (driver.callDeadlines()?.stretchedReadBaseline ?? .zero) * reads)
    }

    /// `observeAfterAction` with a watcher. A change that leaves the elements as they were, such as a tap's touch-down
    /// highlight settling before the transition starts, does not end the wait: it waits for the next change, until the
    /// elements differ from `previous` or the deadline passes. With no change at all the screen is read once at the
    /// deadline, and the step records no visible effect as without a watcher.
    func observeWatching(
        _ screen: any ScreenChangeWatching, changedFrom previous: UISnapshot, since actedAt: ContinuousClock.Instant,
        watch: StepWatch?,
    ) async throws -> ScreenObservation {
        watch?.pause()
        defer { watch?.resume() }
        // The span starts once the action returned, as the polling wait's did; changes count from when it was sent.
        let deadline = ContinuousClock.now.advanced(by: waitSpan(configuration.unchangedWait, reads: configuration.minUnchangedReads))
        var since = actedAt
        var disappeared: [String] = []
        while true {
            let changed = try await settle(screen, changedAfter: since, until: deadline)
            since = .now
            let reading = try await driver.observe()
            disappeared += reading.disappearedApps
            let waiting = reading.snapshot.isBlank || reading.snapshot.identity == previous.identity
            if !waiting || !changed || ContinuousClock.now >= deadline {
                return ScreenObservation(snapshot: reading.snapshot, disappearedApps: disappeared)
            }
        }
    }

    /// `reading(changedFrom:)` with a watcher: a change whose reading shows the same layout (a caret blinking) keeps
    /// the wait going, and without any change the screen is read once, at the deadline, for an app that disappeared.
    func readingWatching(
        _ screen: any ScreenChangeWatching, changedFrom snapshot: UISnapshot, since readAt: ContinuousClock.Instant,
    ) async throws -> (reading: ScreenObservation, changed: Bool) {
        let deadline = ContinuousClock.now.advanced(by: waitSpan(configuration.handOverWait, reads: configuration.minHandOverReads))
        var since = readAt
        var disappeared: [String] = []
        var last: ScreenObservation?
        while true {
            let changed = try await settle(screen, changedAfter: since, until: deadline)
            if !changed, last != nil {
                break
            }
            since = .now
            let reading = try await driver.observe()
            disappeared += reading.disappearedApps
            last = reading
            if !reading.snapshot.isBlank, reading.snapshot.layout != snapshot.layout {
                return (ScreenObservation(snapshot: reading.snapshot, disappearedApps: disappeared), true)
            }
            if !changed || ContinuousClock.now >= deadline {
                break
            }
        }
        return (ScreenObservation(snapshot: last?.snapshot ?? snapshot, disappearedApps: disappeared), false)
    }

    /// Waits for a change after `instant` until `deadline`, then for the image to settle, for `settleWait` at most so a
    /// screen that never stops moving is read anyway; whether it changed.
    private func settle(
        _ screen: any ScreenChangeWatching, changedAfter instant: ContinuousClock.Instant, until deadline: ContinuousClock.Instant,
    ) async throws -> Bool {
        guard try await screen.waitForChange(after: instant, until: deadline) else { return false }
        _ = try await screen.waitUntilStill(for: configuration.quietPeriod, until: .now.advanced(by: configuration.settleWait))
        return true
    }
}

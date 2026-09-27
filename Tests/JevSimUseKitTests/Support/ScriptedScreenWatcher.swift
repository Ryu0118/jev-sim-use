@testable import JevSimUseKit
import Synchronization

/// Answers the loop's screen-change waits from a script, in order (repeating the last), and records how long each
/// wait was allowed. A wait answered `false` sleeps until its deadline, as a live watcher that saw nothing does.
final class ScriptedScreenWatcher: ScreenChangeWatching {
    private let changes: [Bool]
    private let stills: [Bool]
    private let state = Mutex((changes: 0, stills: 0, changeSpans: [Duration]()))

    /// How many times the loop waited for a change.
    var changeWaits: Int {
        state.withLock { $0.changes }
    }

    /// How many times the loop waited for the screen to go still.
    var stillWaits: Int {
        state.withLock { $0.stills }
    }

    /// How long each wait for a change was allowed to run, from the moment it was asked.
    var changeSpans: [Duration] {
        state.withLock { $0.changeSpans }
    }

    init(changes: [Bool], stills: [Bool] = [true]) {
        self.changes = changes
        self.stills = stills
    }

    func waitForChange(after _: ContinuousClock.Instant, until deadline: ContinuousClock.Instant) async throws -> Bool {
        let changed = state.withLock { state in
            defer { state.changes += 1 }
            state.changeSpans.append(deadline - .now)
            return changes[min(state.changes, changes.count - 1)]
        }
        if !changed {
            try await Task.sleep(until: deadline)
        }
        return changed
    }

    func waitUntilStill(for _: Duration, until deadline: ContinuousClock.Instant) async throws -> Bool {
        let still = state.withLock { state in
            defer { state.stills += 1 }
            return stills[min(state.stills, stills.count - 1)]
        }
        if !still {
            try await Task.sleep(until: deadline)
        }
        return still
    }
}

@testable import JevSimUseKit
import Synchronization

/// Opens `watcher` for any simulator, or fails with `failure`, and records the ids it was asked for.
final class RecordingScreenWatchOpener: ScreenWatchOpening {
    let watcher = ScriptedScreenWatcher(changes: [true])
    private let failure: ScreenWatchError?
    private let opened = Mutex<[String]>([])

    /// The simulator ids a watcher was asked for, in order.
    var openedIDs: [String] {
        opened.withLock { $0 }
    }

    init(failure: ScreenWatchError? = nil) {
        self.failure = failure
    }

    func open(simulatorID: String) async throws(ScreenWatchError) -> any ClosableScreenWatcher {
        opened.withLock { $0.append(simulatorID) }
        if let failure {
            throw failure
        }
        return watcher
    }
}

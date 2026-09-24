import Foundation
import Synchronization

/// Drains a pipe while the child runs, so a large output cannot fill the pipe
/// buffer and deadlock the child.
final class PipeCollector: Sendable {
    let pipe = Pipe()
    private let buffer = Mutex(Data())

    /// Starts draining. `group` is left once the pipe reaches end of file.
    func start(group: DispatchGroup) {
        group.enter()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else {
                handle.readabilityHandler = nil
                group.leave()
                return
            }
            self.buffer.withLock { $0.append(chunk) }
        }
    }

    /// Stops draining and returns everything collected so far.
    func finish() -> Data {
        pipe.fileHandleForReading.readabilityHandler = nil
        return buffer.withLock { $0 }
    }
}

import Foundation
import Synchronization

/// Drains a pipe while the child runs, so a large output cannot fill the pipe
/// buffer and deadlock the child.
final class PipeCollector: Sendable {
    private let buffer = Mutex(Data())

    var data: Data {
        buffer.withLock { $0 }
    }

    /// Starts draining. `group` is left once the pipe reaches end of file.
    func drain(_ handle: FileHandle, group: DispatchGroup) {
        group.enter()
        handle.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else {
                handle.readabilityHandler = nil
                group.leave()
                return
            }
            self.buffer.withLock { $0.append(chunk) }
        }
    }
}

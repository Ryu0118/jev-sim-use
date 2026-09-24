import Foundation

/// Lists, shows, and adds notes to saved sessions.
package struct SessionRunner: Sendable {
    private let store: SessionStore
    private let now: @Sendable () -> Date

    package init(store: SessionStore, now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.now = now
    }

    /// Performs `operation`.
    package func run(_ operation: SessionOperation) throws -> SessionOutcome {
        switch operation {
        case .list:
            return try .sessions(store.list())
        case let .show(id):
            return try .session(store.load(id))
        case let .tell(id, note):
            var session = try store.load(id)
            session.notes.append(note)
            session.updatedAt = now()
            try store.save(session)
            return .session(session)
        }
    }
}

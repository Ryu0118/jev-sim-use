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
        try store.removeExpired(now: now())
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
        case let .forget(id, number):
            var session = try store.load(id)
            guard session.notes.indices.contains(number - 1) else {
                throw SessionStoreError.noSuchNote(number: number, count: session.notes.count)
            }
            session.notes.remove(at: number - 1)
            session.updatedAt = now()
            try store.save(session)
            return .session(session)
        }
    }
}

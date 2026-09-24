import Foundation
@testable import JevSimUseKit
import Testing

struct SessionRunnerTests {
    private let store = SessionStore(environment: [
        "XDG_STATE_HOME": TemporaryPath().directory.path(),
    ])

    @Test("tell appends a note to the latest session and makes it the most recent")
    func tell() throws {
        try store.save(SessionRecord(id: "a", goal: "g", texts: [], updatedAt: Date(timeIntervalSince1970: 0)))
        try store.save(SessionRecord(id: "b", goal: "g", texts: [], updatedAt: Date(timeIntervalSince1970: 10)))
        let runner = SessionRunner(store: store, now: { Date(timeIntervalSince1970: 20) })
        let outcome = try runner.run(.tell(id: "a", note: "Dark mode is under Developer."))
        let latest = try store.load(nil)
        #expect(outcome == .session(latest))
        #expect(latest.id == "a")
        #expect(latest.notes == ["Dark mode is under Developer."])
    }

    @Test("forget removes a note by its 1-based number and rejects numbers the session does not have")
    func forget() throws {
        var session = SessionRecord(id: "a", goal: "g", texts: [], updatedAt: Date())
        session.notes = ["wrong", "right"]
        try store.save(session)
        let runner = SessionRunner(store: store)
        _ = try runner.run(.forget(id: "a", number: 1))
        #expect(try store.load("a").notes == ["right"])
        #expect(throws: SessionStoreError.noSuchNote(number: 2, count: 1)) { try runner.run(.forget(id: "a", number: 2)) }
    }
}

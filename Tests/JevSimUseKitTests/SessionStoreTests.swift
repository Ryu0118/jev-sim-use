import Foundation
@testable import JevSimUseKit
import Testing

struct SessionStoreTests {
    private let store = SessionStore(environment: [
        "XDG_STATE_HOME": FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).path(),
    ])

    @Test("round-trips a session with notes, history, and runs")
    func roundTrip() throws {
        var session = SessionRecord(id: "a1", goal: "g", texts: ["t"], deviceID: "D", createdAt: Date(timeIntervalSince1970: 0))
        session.notes = ["Dark mode is under Developer."]
        session.history = [HistoryEntry(step: 1, action: "Tap e3", screenChanged: true)]
        session.runs = [SessionRun(endedAt: Date(timeIntervalSince1970: 5), steps: 1, succeeded: false, outcome: "Stopped.")]
        try store.save(session)
        #expect(try store.load("a1") == session)
        #expect(store.directory.path(percentEncoded: false).hasSuffix("jev-sim-use/sessions"))
    }

    @Test("a missing id loads the most recently updated session")
    func latest() throws {
        var older = SessionRecord(id: "old", goal: "g", texts: [], deviceID: "D", createdAt: Date(timeIntervalSince1970: 0))
        let newer = SessionRecord(id: "new", goal: "g", texts: [], deviceID: "D", createdAt: Date(timeIntervalSince1970: 10))
        try store.save(newer)
        older.updatedAt = Date(timeIntervalSince1970: 20)
        try store.save(older)
        #expect(try store.load(nil).id == "old")
        #expect(try store.list().map(\.id) == ["old", "new"])
    }

    @Test("reports an unknown id and an empty store")
    func missing() {
        #expect(throws: SessionStoreError.notFound(id: "nope")) { try store.load("nope") }
        #expect(throws: SessionStoreError.empty) { try store.load(nil) }
    }
}

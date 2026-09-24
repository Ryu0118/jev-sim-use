import Foundation
@testable import JevSimUseKit
import Testing

struct SessionStoreTests {
    private let store = SessionStore(environment: [
        "XDG_STATE_HOME": TemporaryPath().directory.path(),
    ])

    @Test("round-trips a session with notes, history, and runs")
    func roundTrip() throws {
        var session = SessionRecord(id: "a1", goal: "g", texts: ["t"], deviceID: "D", updatedAt: Date(timeIntervalSince1970: 0))
        session.notes = ["Dark mode is under Developer."]
        session.history = [HistoryEntry(step: 1, action: "Tap e3", screenChanged: true)]
        session.runs = [SessionRun(endedAt: Date(timeIntervalSince1970: 5), steps: 1, outcome: "Stopped.")]
        try store.save(session)
        #expect(try store.load("a1") == session)
        #expect(store.directory.path(percentEncoded: false).hasSuffix("jev-sim-use/sessions"))
    }

    @Test("a missing id loads the most recently updated session")
    func latest() throws {
        var older = SessionRecord(id: "old", goal: "g", texts: [], deviceID: "D", updatedAt: Date(timeIntervalSince1970: 0))
        let newer = SessionRecord(id: "new", goal: "g", texts: [], deviceID: "D", updatedAt: Date(timeIntervalSince1970: 10))
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

    @Test("removes sessions untouched for longer than a week, keeps newer ones")
    func expiry() throws {
        let now = Date(timeIntervalSince1970: 30 * 24 * 60 * 60)
        try store.save(SessionRecord(id: "stale", goal: "g", texts: [], updatedAt: now - SessionStore.timeToLive - 1))
        try store.save(SessionRecord(id: "fresh", goal: "g", texts: [], updatedAt: now - SessionStore.timeToLive + 60))
        try store.removeExpired(now: now)
        #expect(try store.list().map(\.id) == ["fresh"])
    }

    @Test("skips a file that does not decode, and removes it when pruning")
    func corruptFile() throws {
        try store.save(SessionRecord(id: "good", goal: "g", texts: [], updatedAt: Date()))
        let broken = store.directory.appending(path: "broken.json")
        FileManager.default.createFile(atPath: broken.path(percentEncoded: false), contents: Data("{broken".utf8))
        #expect(try store.list().map(\.id) == ["good"])
        try store.removeExpired(now: Date())
        #expect(!FileManager.default.fileExists(atPath: broken.path(percentEncoded: false)))
    }
}

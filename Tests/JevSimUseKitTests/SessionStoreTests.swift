import Foundation
@testable import JevSimUseKit
import Testing

/// Saving, loading, telling, and resuming sessions run end to end (scripts/e2e.sh); these are the store's failure modes
/// a run cannot reach in seconds or should never reach at all.
@Suite("The session store expires stale sessions, survives a broken file, and never leaves its directory")
struct SessionStoreTests {
    private let store = SessionStore(environment: [
        "XDG_STATE_HOME": TemporaryPath().directory.path(),
    ])

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

    @Test("refuses ids that could leave the sessions directory", arguments: ["../../etc/x", "a/b", "..", ""])
    func traversal(id: String) {
        #expect(throws: SessionStoreError.notFound(id: id)) { try store.load(id) }
        #expect(throws: SessionStoreError.notFound(id: id)) { try store.delete(id) }
    }

    @Test("writes sessions readable only by the user")
    func permissions() throws {
        try store.save(SessionRecord(id: "p1", goal: "g", texts: [InputText(name: "password", value: "secret")], updatedAt: Date()))
        let file = try FileManager.default.attributesOfItem(atPath: store.directory.appending(path: "p1.json").path(percentEncoded: false))
        let directory = try FileManager.default.attributesOfItem(atPath: store.directory.path(percentEncoded: false))
        #expect((file[.posixPermissions] as? Int) == 0o600)
        #expect((directory[.posixPermissions] as? Int) == 0o700)
    }
}

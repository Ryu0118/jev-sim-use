import Foundation
@testable import JevSimUseKit
import Testing

struct SessionRunnerTests {
    private let store = SessionStore(environment: [
        "XDG_STATE_HOME": FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).path(),
    ])

    @Test("tell appends a note to the latest session and makes it the most recent")
    func tell() throws {
        try store.save(SessionRecord(id: "a", goal: "g", texts: [], createdAt: Date(timeIntervalSince1970: 0)))
        try store.save(SessionRecord(id: "b", goal: "g", texts: [], createdAt: Date(timeIntervalSince1970: 10)))
        let runner = SessionRunner(store: store, now: { Date(timeIntervalSince1970: 20) })
        let outcome = try runner.run(.tell(id: "a", note: "Dark mode is under Developer."))
        let latest = try store.load(nil)
        #expect(outcome == .session(latest))
        #expect(latest.id == "a")
        #expect(latest.notes == ["Dark mode is under Developer."])
    }
}

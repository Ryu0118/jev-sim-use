import Foundation
@testable import JevSimUseCLI
import JevSimUseKit
import Testing

struct SessionCommandTests {
    @Test("tell adds a note that show prints for the most recent session")
    func tellThenShow() async throws {
        let environment = try FakeSimUse().environment()
        try SessionStore(environment: environment).save(SessionRecord(id: "s1", goal: "Turn on dark mode", texts: [], createdAt: Date()))
        let recording = RecordingOutput()
        let context = CLIContext(output: recording.output, environment: environment)
        try await SessionCommand.Tell.parse(["-n", "The switch is under Developer."]).run(context: context)
        try await SessionCommand.Show.parse([]).run(context: context)
        #expect(recording.standardOutput.contains("  - The switch is under Developer."))
        #expect(recording.standardOutput.last(where: { $0.hasPrefix("Session:") }) == "Session: s1 (not run)")
    }

    @Test("resume exits 2 with a hint when no session exists")
    func resumeWithoutSessions() async throws {
        let recording = RecordingOutput()
        var environment = try FakeSimUse().environment()
        environment["TYPESAFE_API_KEY"] = "k"
        let context = CLIContext(output: recording.output, environment: environment)
        let status = try await ExitStatusCapture.status {
            try await SessionCommand.Resume.parse([]).run(context: context)
        }
        #expect(status == 2)
        #expect(recording.standardError.first?.contains("No sessions yet") == true)
    }

    @Test("rejects an empty note")
    func emptyNote() {
        #expect(throws: (any Error).self) { try SessionCommand.Tell.parse(["-n", " "]) }
    }
}

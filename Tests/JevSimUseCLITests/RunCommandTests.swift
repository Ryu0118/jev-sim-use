@testable import JevSimUseCLI
import JevSimUseKit
import Testing

struct RunCommandTests {
    @Test("exits 2 with the key hint when TYPESAFE_API_KEY is missing")
    func missingKey() async throws {
        let recording = RecordingOutput()
        let context = try CLIContext(output: recording.output, environment: FakeSimUse().environment())
        let status = try await ExitStatusCapture.status {
            try await RunCommand.parse(["Open Settings"]).run(context: context)
        }
        #expect(status == 2)
        #expect(recording.standardOutput.isEmpty)
        #expect(recording.standardError.first?.contains("TYPESAFE_API_KEY") == true)
    }

    @Test("exits 2 with the install hint when sim-use is not on PATH")
    func missingSimUse() async throws {
        let recording = RecordingOutput()
        let context = CLIContext(output: recording.output, environment: ["PATH": "/missing", "TYPESAFE_API_KEY": "k"])
        let status = try await ExitStatusCapture.status {
            try await RunCommand.parse(["Open Settings"]).run(context: context)
        }
        #expect(status == 2)
        #expect(recording.standardError.first?.contains("brew install lycorp-jp/tap/sim-use") == true)
    }

    @Test("rejects out-of-range options before running", arguments: [["x", "--max-steps", "0"], ["x", "--min-confidence", "2"]])
    func invalidOptions(arguments: [String]) {
        #expect(throws: (any Error).self) { try RunCommand.parse(arguments) }
    }

    @Test("parses -t as name=value, keeping any = in the value")
    func namedTexts() throws {
        let command = try RunCommand.parse(["Log in", "-t", "email=alice@example.com", "-t", "password=a=b"])
        #expect(command.texts == [
            InputText(name: "email", value: "alice@example.com"), InputText(name: "password", value: "a=b"),
        ])
    }

    @Test("rejects a -t without a name, and two with the same name", arguments: [
        ["x", "-t", "ramen"], ["x", "-t", "=ramen"], ["x", "-t", "q=a", "-t", "q=b"],
    ])
    func invalidTexts(arguments: [String]) {
        #expect(throws: (any Error).self) { try RunCommand.parse(arguments) }
    }
}

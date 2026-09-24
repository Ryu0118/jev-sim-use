import Foundation
@testable import SimJevUseKit
import Testing

struct SimUseClientTests {
    private let device = ["--device", "B34F0000-0000-0000-0000-000000000001"]

    private func client(_ runner: FakeCommandRunner) throws -> SimUseClient {
        let device = try JSONDecoder().decode(SimUseDevice.self, from: Data(Fixtures.simulator.utf8))
        let invoker = SimUseInvoker(executable: URL(filePath: "/sim-use"), runner: runner)
        return SimUseClient(device: device, invoker: invoker)
    }

    @Test("decodes describe-ui leniently and reports disappeared apps")
    func observe() async throws {
        let runner = FakeCommandRunner(["ui": .json("""
        {"ok":true,"data":{"platform":"ios","orientation":"portrait","outline":"App: Share  402x874",\
        "entries":[{"aliases":{"at":1},"role":"Cell","label":"Alice",\
        "frame":{"x":0,"y":140,"width":402,"height":60},\
        "region":{"kind":"Content"},"states":[]}],"lists":[],"appLabel":"Share","appPackage":"com.x"},\
        "process":{"events":[{"bundleId":"com.x","confidence":"high","kind":"disappeared","pid":100}],"pending":[]}}
        """)])
        let observation = try await client(runner).observe()
        #expect(observation.snapshot.entries?.first?.label == "Alice")
        #expect(observation.disappearedApps == ["com.x"])
        #expect(runner.recordedCalls == [["ui", "--no-raw"] + device + ["--json"]])
    }

    @Test("surfaces the error envelope with its hint")
    func errorEnvelope() async throws {
        let envelope = #"{"ok":false,"error":"No snapshot","hint":"Run ui"}"#
        let runner = FakeCommandRunner(["tap": .json(envelope, exitCode: 1)])
        let expected = SimUseError.commandFailed(
            arguments: ["tap", "@3"] + device, message: "No snapshot", hint: "Run ui",
        )
        await #expect(throws: expected) {
            try await client(runner).tap(alias: 3)
        }
    }

    @Test("reports stderr when validation fails before any JSON is written")
    func validationFailure() async throws {
        let output = CommandOutput(exitCode: 64, stdout: Data(), stderr: "Error: Missing text\n")
        let runner = FakeCommandRunner(["paste": output])
        let expected = SimUseError.malformedOutput(arguments: ["paste"] + device, detail: "Error: Missing text")
        await #expect(throws: expected) {
            try await client(runner).paste("")
        }
    }

    @Test("passes paste text after a terminator so it is never parsed as an option")
    func pasteTerminator() async throws {
        let runner = FakeCommandRunner(["paste": .json(#"{"ok":true,"data":{}}"#)])
        _ = try await client(runner).paste("-5")
        #expect(runner.recordedCalls == [["paste"] + device + ["--json", "--", "-5"]])
    }
}

import Foundation
@testable import JevSimUseKit
import Testing

struct SimUseClientTests {
    private let device = ["--device", "B34F0000-0000-0000-0000-000000000001"]
    private let hiddenKeyboard = CommandOutput.json(#"{"ok":true,"data":{"visible":false,"platform":"ios"}}"#)

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
            try await client(runner).tap(alias: 3, on: Fixtures.snapshot())
        }
    }

    @Test("reports stderr when validation fails before any JSON is written")
    func validationFailure() async throws {
        let output = CommandOutput(exitCode: 64, stdout: Data(), stderr: "Error: Missing text\n")
        let runner = FakeCommandRunner(["paste": output, "keyboard-state": hiddenKeyboard])
        let expected = SimUseError.malformedOutput(arguments: ["paste"] + device, detail: "Error: Missing text")
        await #expect(throws: expected) {
            try await client(runner).paste("")
        }
    }

    @Test("passes paste text after a terminator so it is never parsed as an option")
    func pasteTerminator() async throws {
        let runner = FakeCommandRunner(["paste": .json(#"{"ok":true,"data":{}}"#), "keyboard-state": hiddenKeyboard])
        _ = try await client(runner).paste("-5")
        #expect(runner.recordedCalls.last == ["paste"] + device + ["--json", "--", "-5"])
    }

    @Test("stops before pasting while only the software keyboard is up, since iOS would drop the paste silently")
    func softKeyboard() async throws {
        let runner = FakeCommandRunner([
            "paste": .json(#"{"ok":true,"data":{}}"#),
            "keyboard-state": .json(#"{"ok":true,"data":{"visible":true,"platform":"ios"}}"#),
        ])
        await #expect(throws: SimUseError.hardwareKeyboardRequired) {
            try await client(runner).paste("牛乳を買う")
        }
        #expect(runner.recordedCalls == [["keyboard-state"] + device + ["--json"]])
    }

    @Test("taps an iOS switch on its trailing edge with a short hold, which a row-centre instant tap does not flip")
    func switchTap() async throws {
        let runner = FakeCommandRunner(["tap": .json(#"{"ok":true,"data":{}}"#)])
        let toggle = Fixtures.entry(9, "Dark Appearance", role: "CheckBox", frame: ElementFrame(x: 36, y: 184, width: 330, height: 28))
        let snapshot = Fixtures.snapshot(entries: [toggle, Fixtures.entry(4, "Wi-Fi")])
        _ = try await client(runner).tap(alias: 9, on: snapshot)
        _ = try await client(runner).tap(alias: 4, on: snapshot)
        #expect(runner.recordedCalls == [
            ["tap", "-x", "340.0", "-y", "198.0", "--duration", "0.05"] + device + ["--json"],
            ["tap", "@4"] + device + ["--json"],
        ])
    }

    @Test("aims long-press at the alias, swipes across the frame, and pinches at its centre", arguments: [
        (ElementGesture.longPress, ["long-press", "@9"]),
        (.swipeLeft, ["swipe", "--from", "336.0,200.0", "--to", "200.0,200.0"]),
        (.pinchOut, ["gesture", "pinch-out", "--center-x", "200.0", "--center-y", "200.0"]),
    ])
    func elementGestures(gesture: ElementGesture, expected: [String]) async throws {
        let runner = FakeCommandRunner(["long-press": .json(#"{"ok":true,"data":{}}"#), "swipe": .json(#"{"ok":true,"data":{}}"#),
                                        "gesture": .json(#"{"ok":true,"data":{}}"#)])
        let entry = Fixtures.entry(9, "Row", frame: ElementFrame(x: 30, y: 150, width: 340, height: 100))
        _ = try await client(runner).perform(gesture, alias: 9, on: Fixtures.snapshot(entries: [entry]))
        #expect(runner.recordedCalls == [expected + device + ["--json"]])
    }
}

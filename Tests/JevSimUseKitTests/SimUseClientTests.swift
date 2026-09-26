import Foundation
@testable import JevSimUseKit
import Testing

/// What each action sends to sim-use and how a failed command is read. Taps by alias outside the daemon, a switch's
/// trailing-edge tap, pasting after `--`, the keyboard check, Return, and an error envelope run end to end against the
/// fake sim-use in scripts/e2e.sh; these are the rest of sim-use's argument contract and its failure shapes.
struct SimUseClientTests {
    private static let device = ["--device", "B34F0000-0000-0000-0000-000000000001"]

    private static func client(_ runner: FakeCommandRunner) throws -> SimUseClient {
        SimUseClient(device: Fixtures.device(Fixtures.simulator), invoker: SimUseInvoker(executable: URL(filePath: "/sim-use"), runner: runner))
    }

    private static func entry(_ role: String, value: String? = nil, _ frame: ElementFrame) -> UIEntry {
        Fixtures.entry(9, "Target", role: role, value: value, frame: frame)
    }

    private static let row = ElementFrame(x: 30, y: 150, width: 340, height: 100)

    @Test("aims each element action where the element answers it", arguments: [
        ("a switch: its trailing edge, held briefly", entry("CheckBox", ElementFrame(x: 36, y: 184, width: 330, height: 28)),
         ElementGesture?.none, ["tap", "-x", "340.0", "-y", "198.0", "--duration", "0.05"]),
        ("a full-width value row: its trailing control, held briefly",
         entry("Button", value: "Azure", ElementFrame(x: 32, y: 406, width: 338, height: 28)), nil,
         ["tap", "-x", "352.0", "-y", "420.0", "--duration", "0.05"]),
        ("a narrow button with a value: its alias", entry("Button", value: "2026/09/25", ElementFrame(x: 253, y: 692, width: 110, height: 33)),
         nil, ["tap", "@9"]),
        ("a long press: the alias", entry("Button", row), .longPress, ["long-press", "@9"]),
        ("a sideways swipe: 40% of the width, short of a row's full delete swipe", entry("Button", row), .swipeLeft,
         ["swipe", "--from", "336.0,200.0", "--to", "200.0,200.0"]),
        ("a two-finger gesture: the element's centre", entry("Button", row), .pinchOut,
         ["gesture", "pinch-out", "--center-x", "200.0", "--center-y", "200.0"]),
    ] as [(String, UIEntry, ElementGesture?, [String])])
    func elementAction(_: String, target: UIEntry, gesture: ElementGesture?, expected: [String]) async throws {
        let ok = CommandOutput.json(#"{"ok":true,"data":{}}"#)
        let runner = FakeCommandRunner(["tap": ok, "long-press": ok, "swipe": ok, "gesture": ok])
        let snapshot = Fixtures.snapshot(entries: [target])
        if let gesture {
            _ = try await Self.client(runner).perform(gesture, alias: 9, on: snapshot)
        } else {
            _ = try await Self.client(runner).tap(alias: 9, on: snapshot)
        }
        #expect(runner.recordedCalls == [expected + Self.device + ["--json"]])
    }

    @Test("reads every way a sim-use command can fail", arguments: [
        ("an error envelope on stdout with its hint", CommandOutput.json(#"{"ok":false,"error":"No snapshot","hint":"Run ui"}"#, exitCode: 1),
         SimUseError.commandFailed(arguments: ["tap", "@3"] + device, message: "No snapshot", hint: "Run ui")),
        ("argument validation: plain text on stderr and no JSON", CommandOutput(exitCode: 64, stdout: Data(), stderr: "Error: Missing text\n"),
         .malformedOutput(arguments: ["tap", "@3"] + device, detail: "Error: Missing text")),
        ("no output at all", CommandOutput(exitCode: 9, stdout: Data(), stderr: ""),
         .malformedOutput(arguments: ["tap", "@3"] + device, detail: "exit status 9 with no JSON output")),
    ] as [(String, CommandOutput, SimUseError)])
    func failure(_: String, output: CommandOutput, expected: SimUseError) async throws {
        let client = try Self.client(FakeCommandRunner(["tap": output]))
        await #expect(throws: expected) { try await client.tap(alias: 3, on: Fixtures.snapshot()) }
    }

    @Test("runs every iOS tap outside the daemon, which checks for crashed apps and doubles a tap's time")
    func noDaemon() async throws {
        let runner = FakeCommandRunner(["tap": .json(#"{"ok":true,"data":{}}"#)])
        let toggle = Fixtures.entry(9, "Switch", role: "CheckBox", frame: ElementFrame(x: 36, y: 184, width: 330, height: 28))
        let snapshot = Fixtures.snapshot(entries: [toggle, Fixtures.entry(4, "Row")])
        _ = try await Self.client(runner).tap(alias: 9, on: snapshot)
        _ = try await Self.client(runner).tap(alias: 4, on: snapshot)
        #expect(runner.recordedEnvironments == [["SIM_USE_NO_DAEMON": "1"], ["SIM_USE_NO_DAEMON": "1"]])
    }

    @Test("passes paste text after a terminator so it is never parsed as an option")
    func pasteTerminator() async throws {
        let runner = FakeCommandRunner([
            "paste": .json(#"{"ok":true,"data":{}}"#),
            "keyboard-state": .json(#"{"ok":true,"data":{"visible":false,"platform":"ios"}}"#),
        ])
        _ = try await Self.client(runner).paste("-5")
        #expect(runner.recordedCalls.last == ["paste"] + Self.device + ["--json", "--", "-5"])
    }

    @Test("stops before pasting while only the software keyboard is up, since iOS would drop the paste silently")
    func softKeyboard() async throws {
        let runner = FakeCommandRunner([
            "paste": .json(#"{"ok":true,"data":{}}"#),
            "keyboard-state": .json(#"{"ok":true,"data":{"visible":true,"platform":"ios"}}"#),
        ])
        await #expect(throws: SimUseError.hardwareKeyboardRequired) { try await Self.client(runner).paste("text") }
        #expect(runner.recordedCalls == [["keyboard-state"] + Self.device + ["--json"]])
    }
}

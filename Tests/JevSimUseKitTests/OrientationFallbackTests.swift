import Foundation
@testable import JevSimUseKit
import Testing

/// sim-use sometimes cannot confirm the screen's orientation and then assumes landscape-right, which was wrong on a
/// simulator turned to landscape-left. The simulator's own device orientation settles which landscape it is.
struct OrientationFallbackTests {
    private static let fallback = #""advisory":{"kind":"orientation_calibration_fallback","message":"m"},"#

    private static func reading(advisory: Bool, width: Int = 874, height: Int = 402) -> CommandOutput {
        .json(#"""
        {\#(advisory ? fallback : "")"ok":true,"data":{"platform":"ios","outline":"o","orientation":"landscape-right",
        "screen":{"x":0,"y":0,"width":\#(width),"height":\#(height)},"entries":[]}}
        """#)
    }

    private static func orientation(ui: CommandOutput, device: CommandOutput?) async throws -> (String?, [[String]]) {
        var outputs = ["ui": ui]
        outputs["simctl"] = device
        let runner = FakeCommandRunner(outputs)
        let client = SimUseClient(
            device: Fixtures.device(Fixtures.simulator), invoker: SimUseInvoker(executable: URL(filePath: "/sim-use"), runner: runner),
        )
        return try await (client.read().snapshot.orientation, runner.recordedCalls.map { Array($0.prefix(2)) })
    }

    @Test("takes the simulator's landscape side when sim-use only assumed one", arguments: [
        ("com.apple.backboardd.orientation 4\n", "landscape-left"),
        ("com.apple.backboardd.orientation 3\n", "landscape-right"),
    ])
    func correctsGuess(output: String, expected: String) async throws {
        let (orientation, calls) = try await Self.orientation(ui: Self.reading(advisory: true), device: .text(output))
        #expect(orientation == expected)
        #expect(calls == [["ui", "--device"], ["simctl", "spawn"]])
    }

    @Test("asks nothing more when sim-use confirmed the orientation")
    func confirmed() async throws {
        let (orientation, calls) = try await Self.orientation(ui: Self.reading(advisory: false), device: .text("x 4\n"))
        #expect(orientation == "landscape-right")
        #expect(calls == [["ui", "--device"]])
    }

    @Test("asks nothing more for a portrait screen, which a portrait-only app keeps on a turned device")
    func portraitScreen() async throws {
        let (_, calls) = try await Self.orientation(ui: Self.reading(advisory: true, width: 402, height: 874), device: .text("x 4\n"))
        #expect(calls == [["ui", "--device"]])
    }

    @Test("keeps sim-use's guess when the device is not on a landscape side or cannot be asked", arguments: [
        CommandOutput.text("com.apple.backboardd.orientation 2\n"),
        CommandOutput(exitCode: 1, stdout: Data(), stderr: "Invalid device"),
        CommandOutput.text("garbage"),
    ])
    func keepsGuess(device: CommandOutput) async throws {
        let (orientation, _) = try await Self.orientation(ui: Self.reading(advisory: true), device: device)
        #expect(orientation == "landscape-right")
    }
}

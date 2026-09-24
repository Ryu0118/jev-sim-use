@testable import JevSimUseCLI
import Testing

struct DoctorCommandTests {
    @Test("prints one line per check and exits 1 when any check fails")
    func reportsEachCheck() async throws {
        let recording = RecordingOutput()
        let context = try CLIContext(output: recording.output, environment: FakeSimUse().environment())
        let status = try await ExitStatusCapture.status {
            try await DoctorCommand.parse([]).run(context: context)
        }
        #expect(status == 1)
        #expect(recording.standardOutput.count == 3)
        #expect(recording.standardOutput[0].hasPrefix("✓ sim-use: 0.14.0"))
        #expect(recording.standardOutput[1] == "✓ device: Fake iPhone (FAKE-DEVICE); screen readable, 0 elements")
        #expect(recording.standardOutput[2].hasPrefix("✗ jev: Set TYPESAFE_API_KEY"))
    }

    @Test("skips the device check when sim-use is missing")
    func skipsDevice() async throws {
        let recording = RecordingOutput()
        let context = CLIContext(output: recording.output, environment: ["PATH": "/missing"])
        _ = try await ExitStatusCapture.status { try await DoctorCommand.parse([]).run(context: context) }
        #expect(recording.standardOutput[1] == "– device: skipped, sim-use is not ready")
    }
}

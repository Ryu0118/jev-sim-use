import Foundation
@testable import SimJevUseCLI
import Testing

struct ConfigCommandTests {
    private let environment = [
        "XDG_CONFIG_HOME": FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).path(),
    ]

    @Test("stores a value and lists it through the injected output")
    func setThenList() async throws {
        let recording = RecordingOutput()
        let context = CLIContext(output: recording.output, environment: environment)
        try await ConfigCommand.Set.parse(["base-url", "https://proxy.example"]).run(context: context)
        try await ConfigCommand.List.parse([]).run(context: context)
        #expect(recording.standardOutput == ["base-url=https://proxy.example"])
    }
}

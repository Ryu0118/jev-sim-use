import ArgumentParser
import Foundation
@testable import JevSimUseCLI
import Testing

struct SkillCommandTests {
    private let home = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)

    @Test("installs under the injected HOME and reports the path on stdout")
    func installReportsPath() async throws {
        let recording = RecordingOutput()
        let context = CLIContext(output: recording.output, environment: ["HOME": home.path(percentEncoded: false)])
        try await SkillCommand.Install.parse(["--client", "agents"]).run(context: context)
        let directory = home.appending(path: ".agents/skills/jev-sim-use").path(percentEncoded: false)
        #expect(recording.standardOutput == ["Installed the skill at \(directory)"])
    }

    @Test("rejects both or neither of --client and --dest", arguments: [[], ["--client", "claude", "--dest", "/tmp/skills"]])
    func targetIsExclusive(arguments: [String]) {
        #expect(throws: (any Error).self) { try SkillCommand.Install.parse(arguments) }
    }
}

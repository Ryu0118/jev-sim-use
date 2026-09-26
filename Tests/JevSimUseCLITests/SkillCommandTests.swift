import ArgumentParser
import Foundation
@testable import JevSimUseCLI
import JevSimUseKit
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

    @Test("print without a path writes SKILL.md, and with one writes that bundled file")
    func printsBundledFile() async throws {
        for (arguments, file) in [([], SkillBundle.fileName), (["references/troubleshooting.md"], "references/troubleshooting.md")] {
            let recording = RecordingOutput()
            try await SkillCommand.Print.parse(arguments).run(context: CLIContext(output: recording.output, environment: [:]))
            #expect(try recording.standardOutput == [SkillBundle.contents(of: file)])
        }
    }

    @Test("print rejects an unknown path and lists the bundled files")
    func printRejectsUnknownPath() {
        do {
            _ = try SkillCommand.Print.parse(["nope.md"])
            Issue.record("parsing an unknown path should fail")
        } catch {
            let message = SkillCommand.Print.message(for: error)
            #expect(message.contains("nope.md"))
            #expect(message.contains("references/troubleshooting.md"))
        }
    }
}

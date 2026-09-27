import Foundation
@testable import JevSimUseKit
import Testing

/// How the check of an installed skill against the binary can mislead, listed before it was written. The E2E runs with
/// whatever skill the developer has installed, so each case is set up in a temporary home here.
@Suite("An installed skill is compared with the binary only where it exists, and never breaks a run")
struct SkillVersionCheckTests {
    private let home = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)

    private func install(_ client: SkillClient, skill: String) throws {
        let directory = client.skillsDirectory(home: home).appending(path: SkillBundle.name)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(skill.utf8).write(to: directory.appending(path: SkillBundle.fileName))
    }

    private func warnings(binary: String = "0.3.0") -> [String] {
        SkillVersionCheck(environment: ["HOME": home.path()]).warnings(binaryVersion: binary)
    }

    private static func skill(version: String?) -> String {
        let metadata = version.map { "metadata:\n  version: \"\($0)\"\n" } ?? ""
        return "---\nname: jev-sim-use\ndescription: d\n\(metadata)---\n\n# jev-sim-use\n"
    }

    @Test("stays quiet for a user who never installed the skill")
    func noSkill() {
        #expect(warnings().isEmpty)
    }

    @Test("stays quiet when the installed skill matches, a dev build's suffix aside", arguments: ["0.3.0", "0.3.0-5-gabc123-dirty"])
    func matching(binary: String) throws {
        try install(.claude, skill: Self.skill(version: "0.3.0"))
        #expect(warnings(binary: binary).isEmpty)
    }

    @Test("tells an older skill to be reinstalled for its own client")
    func olderSkill() throws {
        try install(.agents, skill: Self.skill(version: "0.2.0"))
        let lines = warnings()
        #expect(lines.count == 1)
        #expect(lines.first?.contains("0.2.0") == true)
        #expect(lines.first?.contains("jev-sim-use skill install --client agents --force") == true)
    }

    @Test("tells a newer skill that the binary is the side to update")
    func newerSkill() throws {
        try install(.claude, skill: Self.skill(version: "0.4.0"))
        let lines = warnings()
        #expect(lines.count == 1)
        #expect(lines.first?.contains("update jev-sim-use") == true)
    }

    @Test("counts a skill with no version, as every one installed before versions were added, as outdated")
    func unversionedSkill() throws {
        try install(.claude, skill: Self.skill(version: nil))
        #expect(warnings().first?.contains("--client claude --force") == true)
    }

    @Test("reads the version among other metadata, quoted or not, as `gh skill install` adds its own keys")
    func otherMetadata() throws {
        try install(.claude, skill: "---\nname: jev-sim-use\nmetadata:\n  github-repo: o/r\n  version: 0.3.0\n---\n")
        #expect(warnings().isEmpty)
    }

    @Test("checks each client's copy on its own")
    func eachClient() throws {
        try install(.claude, skill: Self.skill(version: "0.3.0"))
        try install(.agents, skill: Self.skill(version: "0.1.0"))
        #expect(warnings().count == 1)
    }

    @Test("warns about a skill file it cannot read instead of failing")
    func unreadable() throws {
        let directory = SkillClient.claude.skillsDirectory(home: home).appending(path: SkillBundle.name)
        // A directory where SKILL.md should be cannot be read as text.
        try FileManager.default.createDirectory(
            at: directory.appending(path: SkillBundle.fileName), withIntermediateDirectories: true,
        )
        #expect(warnings().first?.contains("--client claude --force") == true)
    }

    @Test("ships the skill with the binary's version, so a bump that misses SKILL.md fails here")
    func embeddedSkillMatchesBinary() {
        #expect(SkillBundle.version == JevSimUseVersion.current)
    }
}

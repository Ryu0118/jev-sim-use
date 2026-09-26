import Foundation
@testable import JevSimUseKit
import Testing

struct SkillRunnerTests {
    private let home = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)

    private var runner: SkillRunner {
        SkillRunner(environment: ["HOME": home.path(percentEncoded: false)])
    }

    @Test("writes SKILL.md and its references into each client's skills directory under HOME", arguments: SkillClient.allCases)
    func installForClient(client: SkillClient) throws {
        let outcome = try runner.run(.install(.client(client), force: false))
        let directory = client.skillsDirectory(home: home).appending(path: "jev-sim-use")
        #expect(outcome == .installed(directory))
        let written = try String(contentsOf: directory.appending(path: "SKILL.md"), encoding: .utf8)
        #expect(written == SkillBundle.markdown)
        for (path, contents) in SkillBundle.files {
            #expect(try String(contentsOf: directory.appending(path: path), encoding: .utf8) == contents)
        }
    }

    @Test("refuses to overwrite an installed skill unless forced")
    func overwriteNeedsForce() throws {
        let target = SkillTarget.directory(home.appending(path: "custom"))
        _ = try runner.run(.install(target, force: false))
        #expect(throws: SkillError.self) { try runner.run(.install(target, force: false)) }
        #expect(throws: Never.self) { try runner.run(.install(target, force: true)) }
    }

    @Test("a forced install removes files an older version of the skill left behind")
    func forcedInstallDropsStaleFiles() throws {
        let target = SkillTarget.directory(home.appending(path: "custom"))
        _ = try runner.run(.install(target, force: false))
        let stale = home.appending(path: "custom/jev-sim-use/references/retired.md")
        FileManager.default.createFile(atPath: stale.path(percentEncoded: false), contents: Data("old".utf8))
        _ = try runner.run(.install(target, force: true))
        #expect(!FileManager.default.fileExists(atPath: stale.path(percentEncoded: false)))
    }

    @Test("uninstall removes the skill directory and reports when nothing was there")
    func uninstall() throws {
        let target = SkillTarget.client(.claude)
        let directory = SkillClient.claude.skillsDirectory(home: home).appending(path: "jev-sim-use")
        #expect(try runner.run(.uninstall(target)) == .notInstalled(directory))
        _ = try runner.run(.install(target, force: false))
        #expect(try runner.run(.uninstall(target)) == .uninstalled(directory))
        #expect(!FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)))
    }
}

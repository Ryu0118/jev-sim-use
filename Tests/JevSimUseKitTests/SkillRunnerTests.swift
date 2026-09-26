import Foundation
@testable import JevSimUseKit
import Testing

/// Reinstalling the skill: a user's edited copy is kept unless forced, and a forced install leaves no stale files.
@Suite("skill install protects an existing copy and replaces it whole when forced")
struct SkillRunnerTests {
    private let home = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)

    private var runner: SkillRunner {
        SkillRunner(environment: ["HOME": home.path(percentEncoded: false)])
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
}

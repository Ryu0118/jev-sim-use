import Foundation
@testable import JevSimUseKit
import Testing

struct SkillBundleDriftTests {
    @Test("embedded skill files match skills/jev-sim-use; run `mise run generate-skill` when it fails")
    func embeddedSkillMatchesSource() throws {
        let skill = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "skills/\(SkillBundle.name)")
        let references = (try? FileManager.default.contentsOfDirectory(atPath: skill.appending(path: "references").path()))?
            .filter { $0.hasSuffix(".md") }.sorted().map { "references/\($0)" } ?? []
        #expect(SkillBundle.files.map(\.path) == [SkillBundle.fileName] + references)
        for (path, contents) in SkillBundle.files {
            #expect(try String(contentsOf: skill.appending(path: path), encoding: .utf8) == contents, "\(path) is stale")
        }
    }
}

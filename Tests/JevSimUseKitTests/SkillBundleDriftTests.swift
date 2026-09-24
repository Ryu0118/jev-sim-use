import Foundation
@testable import JevSimUseKit
import Testing

struct SkillBundleDriftTests {
    @Test("embedded skill matches skills/jev-sim-use/SKILL.md; run `mise run generate-skill` when it fails")
    func embeddedSkillMatchesSource() throws {
        let source = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "skills/\(SkillBundle.name)/\(SkillBundle.fileName)")
        let markdown = try String(contentsOf: source, encoding: .utf8)
        #expect(SkillBundle.markdown == markdown)
    }
}

import Foundation
@testable import JevSimUseKit
import Testing

/// The EmbedSkill build plugin compiles skills/jev-sim-use into `SkillBundle.files` on every build, so the embedded
/// skill cannot go stale. What can still go wrong is the plugin itself: a reference file left out, files out of order
/// (`skill print` shows the first), or contents changed on the way, such as a lost trailing newline.
@Suite("The build embeds every skill file in order, byte for byte")
struct SkillEmbeddingTests {
    @Test("embeds SKILL.md first, then every reference sorted by name, each exactly as in skills/jev-sim-use")
    func embeddedSkillMatchesSource() throws {
        let skill = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "skills/\(SkillBundle.name)")
        let references = try FileManager.default.contentsOfDirectory(atPath: skill.appending(path: "references").path())
            .filter { $0.hasSuffix(".md") }.sorted().map { "references/\($0)" }
        #expect(SkillBundle.files.map(\.path) == [SkillBundle.fileName] + references)
        for (path, contents) in SkillBundle.files {
            #expect(try Data(contentsOf: skill.appending(path: path)) == Data(contents.utf8), "\(path) differs")
        }
    }
}

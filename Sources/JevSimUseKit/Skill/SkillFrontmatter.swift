import Foundation

/// Reads the YAML frontmatter of a SKILL.md, as far as this tool needs it.
enum SkillFrontmatter {
    /// `metadata.version`, where the Agent Skills spec lets a skill keep its own properties (Claude Code, Codex, and
    /// `gh skill` accept the map and ignore keys they do not know); `nil` when absent. Only the frontmatter block is
    /// read, and only the two-level `metadata:` / `version:` shape this skill writes, quoted or not.
    static func version(in markdown: String) -> String? {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first == "---", let end = lines.dropFirst().firstIndex(of: "---") else { return nil }
        var inMetadata = false
        for line in lines[1 ..< end] {
            if !line.hasPrefix(" ") {
                inMetadata = line.trimmingCharacters(in: .whitespaces) == "metadata:"
                continue
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard inMetadata, trimmed.hasPrefix("version:") else { continue }
            let value = trimmed.dropFirst("version:".count).trimmingCharacters(in: .whitespaces)
            return value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
        return nil
    }
}

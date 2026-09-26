/// The agent skill shipped inside the binary.
package enum SkillBundle {
    /// The skill's directory name, as agents look it up.
    package static let name = "jev-sim-use"
    /// The skill's entry file.
    package static let fileName = "SKILL.md"

    /// The contents of SKILL.md, which `skill print` shows.
    static var markdown: String {
        files.first { $0.path == fileName }?.contents ?? ""
    }

    /// Every bundled file's path inside the skill directory, SKILL.md first.
    package static var paths: [String] {
        files.map(\.path)
    }

    /// Returns the bundled file at `path` (relative to the skill directory, e.g. `references/troubleshooting.md`).
    /// - Throws: `SkillError.unknownFile` listing `paths` when no bundled file has that path.
    package static func contents(of path: String) throws(SkillError) -> String {
        guard let file = files.first(where: { $0.path == path }) else { throw .unknownFile(path, available: paths) }
        return file.contents
    }
}

import Foundation

/// Agent clients whose skill directory the skill can be installed into; the same set `sim-use init` targets.
package enum SkillClient: String, Sendable, CaseIterable {
    /// Claude Code, which reads `~/.claude/skills`.
    case claude
    /// Clients that read the shared `~/.agents/skills` directory.
    case agents

    /// The directory that holds this client's skills.
    func skillsDirectory(home: URL) -> URL {
        switch self {
        case .claude: home.appending(path: ".claude/skills")
        case .agents: home.appending(path: ".agents/skills")
        }
    }
}

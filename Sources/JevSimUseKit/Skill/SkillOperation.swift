import Foundation

/// What `SkillRunner` should do with the bundled skill.
package enum SkillOperation: Sendable, Equatable {
    /// Writes the skill into `target`, replacing an existing copy only when `force` is set.
    case install(SkillTarget, force: Bool)
    /// Removes the skill from `target`.
    case uninstall(SkillTarget)
    /// Returns the skill's contents without touching the file system.
    case print
}

/// Where the skill lives: a known client's skills directory, or an explicit one.
package enum SkillTarget: Sendable, Equatable {
    /// The skills directory of `SkillClient`.
    case client(SkillClient)
    /// A skills directory given by path; the skill goes in a `jev-sim-use` subdirectory.
    case directory(URL)
}

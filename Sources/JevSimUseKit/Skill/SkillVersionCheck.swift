import FileManagerProtocol
import Foundation

/// Compares each installed copy of the skill (where `skill install` writes it) with this binary, so an agent following
/// instructions for another version is told to update first.
package struct SkillVersionCheck: Sendable {
    private let home: URL
    private let fileManager: any FileManagerProtocol

    /// Resolves client directories against `environment["HOME"]`, falling back to the current user's home.
    package init(environment: [String: String], fileManager: some FileManagerProtocolMacOS = FileManager.default) {
        home = UserDirectories(environment: environment, fileManager: fileManager).home
        self.fileManager = fileManager
    }

    /// One line per installed copy whose version differs from `binaryVersion`, with the command that fixes it. A client
    /// without the skill is not a problem; a copy without a version (installed before skills carried one) or one that
    /// cannot be read counts as outdated. Versions compare by `major.minor.patch`, so a dev build's suffix is ignored.
    package func warnings(binaryVersion: String = JevSimUseVersion.current) -> [String] {
        let binary = SemanticVersion(parsing: binaryVersion)
        return SkillClient.allCases.compactMap { client in
            let file = client.skillsDirectory(home: home).appending(path: "\(SkillBundle.name)/\(SkillBundle.fileName)")
            guard fileManager.fileExists(atPath: file.path(percentEncoded: false)) else { return nil }
            let reinstall = "jev-sim-use skill install --client \(client.rawValue) --force"
            // A copy that cannot be read is replaced the same way as an outdated one.
            let contents = fileManager.contents(atPath: file.path(percentEncoded: false)).flatMap { String(data: $0, encoding: .utf8) }
            let skill = contents.flatMap(SkillFrontmatter.version(in:)).flatMap(SemanticVersion.init(parsing:))
            if let skill, let binary, skill == binary {
                return nil
            }
            let location = file.deletingLastPathComponent().path(percentEncoded: false)
            if let skill, let binary, skill > binary {
                return "The jev-sim-use skill at \(location) is for \(skill), newer than this jev-sim-use \(binary): "
                    + "update jev-sim-use before following it (`jev-sim-use skill print` lists how)."
            }
            let found = contents == nil ? "cannot be read" : "is for \(skill.map(\.description) ?? "an unknown version")"
            return "The jev-sim-use skill at \(location) \(found), but this is jev-sim-use \(binaryVersion): "
                + "update it with `\(reinstall)`."
        }
    }
}

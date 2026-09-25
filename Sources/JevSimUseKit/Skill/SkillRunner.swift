import FileManagerProtocol
import Foundation

/// Installs, removes, or prints the agent skill embedded in the binary.
package struct SkillRunner: Sendable {
    private let home: URL
    private let fileManager: any FileManagerProtocol

    /// Resolves client directories against `environment["HOME"]`, falling back to the current user's home.
    package init(environment: [String: String], fileManager: some FileManagerProtocolMacOS = FileManager.default) {
        home = UserDirectories(environment: environment, fileManager: fileManager).home
        self.fileManager = fileManager
    }

    /// Performs `operation`.
    package func run(_ operation: SkillOperation) throws -> SkillOutcome {
        switch operation {
        case let .install(target, force): try install(into: directory(for: target), force: force)
        case let .uninstall(target): try uninstall(from: directory(for: target))
        case .print: .contents(SkillBundle.markdown)
        }
    }

    private func directory(for target: SkillTarget) -> URL {
        let skills = switch target {
        case let .client(client): client.skillsDirectory(home: home)
        case let .directory(url): url
        }
        return skills.appending(path: SkillBundle.name)
    }

    private func install(into directory: URL, force: Bool) throws -> SkillOutcome {
        guard force || !fileManager.fileExists(atPath: directory.path(percentEncoded: false)) else {
            throw SkillError.alreadyInstalled(directory)
        }
        // SKILL.md points at references/ for detail, so the whole directory is written, not SKILL.md alone.
        for (path, contents) in SkillBundle.files {
            let file = directory.appending(path: path)
            try fileManager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard fileManager.createFile(atPath: file.path(percentEncoded: false), contents: Data(contents.utf8))
            else { throw SkillError.writeFailed(file) }
        }
        return .installed(directory)
    }

    private func uninstall(from directory: URL) throws -> SkillOutcome {
        guard fileManager.fileExists(atPath: directory.path(percentEncoded: false)) else { return .notInstalled(directory) }
        try fileManager.removeItem(at: directory)
        return .uninstalled(directory)
    }
}

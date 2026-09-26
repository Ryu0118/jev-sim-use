import ArgumentParser
import JevSimUseKit

extension SkillCommand {
    struct Install: ContextualCommand {
        static let configuration = CommandConfiguration(abstract: "Install the skill.")

        @OptionGroup var target: TargetOptions

        @Flag(help: "Overwrite an existing installed skill.")
        var force = false

        func run(context: CLIContext) async throws {
            try SkillCommand.perform(.install(target.target, force: force), context: context)
        }
    }

    struct Uninstall: ContextualCommand {
        static let configuration = CommandConfiguration(abstract: "Remove the installed skill.")

        @OptionGroup var target: TargetOptions

        func run(context: CLIContext) async throws {
            try SkillCommand.perform(.uninstall(target.target), context: context)
        }
    }

    struct Print: ContextualCommand {
        static let configuration = CommandConfiguration(
            abstract: "Print the skill's SKILL.md, or one of the files it links to, to stdout.",
            discussion: "Files: \(SkillBundle.paths.joined(separator: ", ")).",
        )

        @Argument(help: "A file's path inside the skill directory, such as references/troubleshooting.md.")
        var path: String?

        func validate() throws {
            guard let path else { return }
            do {
                _ = try SkillBundle.contents(of: path)
            } catch {
                throw ValidationError(error.description)
            }
        }

        func run(context: CLIContext) async throws {
            try SkillCommand.perform(.print(path), context: context)
        }
    }
}

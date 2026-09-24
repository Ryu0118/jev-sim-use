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
        static let configuration = CommandConfiguration(abstract: "Print the skill's SKILL.md to stdout.")

        func run(context: CLIContext) async throws {
            try SkillCommand.perform(.print, context: context)
        }
    }
}

import ArgumentParser
import Foundation
import JevSimUseKit

struct SkillCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "skill",
        abstract: "Install the jev-sim-use agent skill so AI agents delegate navigation to it.",
        discussion: "Uses the same client directories as `sim-use init`: ~/.claude/skills or ~/.agents/skills.",
        subcommands: [Install.self, Uninstall.self, Print.self],
    )
}

extension SkillClient: ExpressibleByArgument {}

extension SkillCommand {
    /// Chooses where the skill lives; exactly one of `--client` or `--dest`.
    struct TargetOptions: ParsableArguments {
        @Option(help: "Agent client whose skills directory to use.")
        var client: SkillClient?

        @Option(help: "Custom skills directory (the skill goes in a jev-sim-use subdirectory).")
        var dest: String?

        var target: SkillTarget {
            get throws {
                switch (client, dest) {
                case let (client?, nil): return .client(client)
                case let (nil, dest?): return .directory(URL(filePath: dest))
                default: throw ValidationError("Pass exactly one of --client or --dest.")
                }
            }
        }

        func validate() throws {
            _ = try target
        }
    }

    /// Runs `operation` and presents the outcome.
    static func perform(_ operation: SkillOperation, context: CLIContext) throws {
        let outcome: SkillOutcome
        do {
            outcome = try SkillRunner(environment: context.environment).run(operation)
        } catch {
            throw context.failure(error)
        }
        switch outcome {
        case let .installed(url): context.output.standardOutput("Installed the skill at \(url.path(percentEncoded: false))")
        case let .uninstalled(url): context.output.standardOutput("Removed the skill from \(url.path(percentEncoded: false))")
        case let .notInstalled(url): context.output.standardOutput("No skill installed at \(url.path(percentEncoded: false))")
        case let .contents(markdown): context.output.standardOutput(markdown)
        }
    }
}

import ArgumentParser
import JevSimUseKit

extension SessionCommand {
    struct List: ContextualCommand {
        static let configuration = CommandConfiguration(abstract: "List sessions, most recent first.")

        func run(context: CLIContext) async throws {
            try SessionCommand.perform(.list, context: context)
        }
    }

    struct Show: ContextualCommand {
        static let configuration = CommandConfiguration(abstract: "Print a session's goal, notes, runs, and recent actions.")

        @Argument(help: "Session id. Default: the most recent session.") var id: String?

        func run(context: CLIContext) async throws {
            try SessionCommand.perform(.show(id: id), context: context)
        }
    }

    struct Tell: ContextualCommand {
        static let configuration = CommandConfiguration(
            abstract: "Add a fact about the app for Jev to use on the next resume.",
            discussion: """
            State facts, not steps: "Dark Mode is the Dark Appearance switch under Developer", \
            "the goal is reached when the Dark Appearance switch is on".
            """,
        )

        @Argument(help: "Session id. Default: the most recent session.") var id: String?
        @Option(name: .shortAndLong, help: "The fact to add.") var note: String

        func validate() throws {
            guard !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError("--note must not be empty.")
            }
        }

        func run(context: CLIContext) async throws {
            try SessionCommand.perform(.tell(id: id, note: note), context: context)
        }
    }

    struct Resume: ContextualCommand {
        static let configuration = CommandConfiguration(
            abstract: "Continue a session's goal from the current screen, with its notes and history.",
            discussion: "Exits like `run`. --max-steps applies to this run only.",
        )

        @Argument(help: "Session id. Default: the most recent session.") var id: String?
        @OptionGroup var connection: ConnectionOptions
        @OptionGroup var agent: AgentOptions

        func run(context: CLIContext) async throws {
            try await RunGoalRequest(session: .resume(id: id), connection: connection, agent: agent)
                .perform(context: context)
        }
    }
}

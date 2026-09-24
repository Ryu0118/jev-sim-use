import ArgumentParser
import JevSimUseKit

struct SessionCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "session",
        abstract: "Inspect a run's session, tell it facts about the app, and resume it.",
        discussion: """
        Every `run` saves a session: the goal, the device, every action, and how each run ended. When a run stops \
        short, `show` it, `tell` it what you know (where a setting lives, what the finished screen looks like), and \
        `resume` it: Jev continues the same goal with the notes and history. Omit the id for the most recent session. \
        Stored in $XDG_STATE_HOME/jev-sim-use/sessions (default ~/.local/state). Reaching the goal deletes the \
        session; an unfinished one expires a week after it last changed.
        """,
        subcommands: [List.self, Show.self, Tell.self, Resume.self],
    )

    /// Runs `operation` against the saved sessions and presents the outcome.
    static func perform(_ operation: SessionOperation, context: CLIContext) throws {
        let outcome: SessionOutcome
        do {
            outcome = try SessionRunner(store: SessionStore(environment: context.environment)).run(operation)
        } catch {
            throw context.failure(error)
        }
        switch outcome {
        case let .sessions(sessions): sessions.forEach { context.output.standardOutput($0.summaryLine) }
        case let .session(session): session.detailLines.forEach(context.output.standardOutput)
        }
    }
}

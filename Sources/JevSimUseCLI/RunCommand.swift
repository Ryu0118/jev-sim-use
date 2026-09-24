import ArgumentParser
import JevSimUseKit

struct RunCommand: ContextualCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Work toward a goal, starting from the current screen (the default command).",
        discussion: """
        Requires $TYPESAFE_API_KEY. The app must already be open: sim-use cannot launch apps. Every run starts a \
        session. When the goal is not reached, stdout ends with `Session: <id>` for `session show`, `session tell`, \
        and `session resume`; reaching the goal deletes the session.
        """,
    )

    @Argument(help: "What to accomplish, in natural language.")
    var goal: String

    @Option(
        name: [.customShort("t"), .customLong("text")],
        help: ArgumentHelp(
            "A string to enter into a field, as name=value (email=alice@example.com). Repeatable.",
            discussion: "Jev never writes text: it sees only the name, picks the field that matches it, and the value is entered for it. The value is not sent to Jev.",
            valueName: "name=value",
        ),
    )
    var texts: [InputText] = []

    @OptionGroup var connection: ConnectionOptions
    @OptionGroup var agent: AgentOptions

    func validate() throws {
        let names = texts.map(\.name)
        guard Set(names).count == names.count else { throw ValidationError("Each -t name must be different.") }
    }

    func run(context: CLIContext) async throws {
        try await RunGoalRequest(session: .new(goal: goal, texts: texts), connection: connection, agent: agent)
            .perform(context: context)
    }
}

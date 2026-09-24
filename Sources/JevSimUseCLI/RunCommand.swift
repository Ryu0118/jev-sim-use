import ArgumentParser
import JevSimUseKit

struct RunCommand: ContextualCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Work toward a goal, starting from the current screen (the default command).",
        discussion: """
        Requires $TYPESAFE_API_KEY. The app must already be open: sim-use cannot launch apps. Every run starts a \
        session; stdout ends with `Session: <id>` for `session show`, `session tell`, and `session resume`.
        """,
    )

    @Argument(help: "What to accomplish, in natural language.")
    var goal: String

    @Option(name: [.customShort("t"), .customLong("text")], help: "Text the agent may paste into fields. Repeatable.")
    var texts: [String] = []

    @OptionGroup var connection: ConnectionOptions
    @OptionGroup var agent: AgentOptions

    func run(context: CLIContext) async throws {
        try await RunGoalRequest(
            session: .new(goal: goal, texts: texts), maxSteps: agent.maxSteps, minConfidence: agent.minConfidence,
            deviceID: connection.device, baseURL: connection.baseURL, model: connection.model,
        ).perform(context: context)
    }
}

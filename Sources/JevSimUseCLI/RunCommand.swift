import ArgumentParser
import Jev
import SimJevUseKit

struct RunCommand: ContextualCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Work toward a goal, starting from the current screen (the default command).",
        discussion: "Requires $TYPESAFE_API_KEY. The app must already be open: sim-use cannot launch apps.",
    )

    @Argument(help: "What to accomplish, in natural language.")
    var goal: String

    @OptionGroup var connection: ConnectionOptions

    @Option(name: [.customShort("t"), .customLong("text")], help: "Text the agent may paste into fields. Repeatable.")
    var texts: [String] = []

    @Option(help: "Maximum number of actions.")
    var maxSteps = 15

    @Option(help: "Stop and hand over when Jev's confidence in the next action is below this (0...1).")
    var minConfidence = RoutingPolicy.default.escalateBelow

    func validate() throws {
        guard maxSteps > 0 else { throw ValidationError("--max-steps must be positive.") }
        guard (0 ... 1).contains(minConfidence) else { throw ValidationError("--min-confidence must be within 0...1.") }
    }

    /// Progress goes to stderr; stdout carries only the final outcome.
    func run(context: CLIContext) async throws {
        let outcome: AgentOutcome
        do {
            outcome = try await execute(context: context)
        } catch {
            context.output.standardError("Error: \(error)")
            throw ExitCode(ExitStatus.of(error))
        }
        context.output.standardOutput("\(outcome)")
        guard outcome.isSuccess else { throw ExitCode.failure }
    }
}

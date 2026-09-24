import ArgumentParser
import Jev
import SimJevUseKit

struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Work toward a goal on the device, starting from the current screen.",
        discussion: "Requires $TYPESAFE_API_KEY. The app must already be open: sim-use cannot launch apps.",
    )

    @Option(help: "What to accomplish, in natural language.")
    var goal: String

    @Option(help: "sim-use device id. Default: the only booted simulator or connected device.")
    var device: String?

    @Option(name: .customLong("text"), help: "Text the agent may paste into fields. Repeatable.")
    var texts: [String] = []

    @Option(help: "Maximum number of actions.")
    var maxSteps = 15

    @Option(help: "Stop when Jev's confidence in the next action is below this value (0...1).")
    var minConfidence = RoutingPolicy.default.escalateBelow

    @OptionGroup var jev: JevOptions

    func validate() throws {
        guard maxSteps > 0 else { throw ValidationError("--max-steps must be positive.") }
        guard (0 ... 1).contains(minConfidence) else { throw ValidationError("--min-confidence must be within 0...1.") }
    }

    func run() async throws {
        let settings = try JevSettings.resolve(endpointFlag: jev.endpoint, modelFlag: jev.model)
        let client = try await SimUseBootstrap().connect(deviceID: device)
        Console.error("Device: \(client.device.name) (\(client.device.deviceId)), Jev: \(settings.endpoint)")
        let policy = RoutingPolicy(escalateBelow: minConfidence, autoAtOrAbove: max(minConfidence, 0.85))
        let loop = AgentLoop(
            driver: client,
            planner: JevStepPlanner(client: settings.makeClient()),
            configuration: AgentConfiguration(goal: goal, texts: texts, maxSteps: maxSteps, policy: policy),
            report: { Console.error($0.description) },
        )
        let outcome = try await loop.run()
        print(outcome)
        guard outcome.isSuccess else { throw ExitCode.failure }
    }
}

import ArgumentParser
import Jev

/// Per-run limits shared by `run` and `session resume`.
struct AgentOptions: ParsableArguments {
    @Option(help: "Maximum number of actions in this run.")
    var maxSteps = 15

    @Option(help: "Below this support (0...1), explore (scroll down, go back) before handing over a tap or scroll. Pasting and buttons need at least 0.85.")
    var minConfidence = RoutingPolicy.default.escalateBelow

    func validate() throws {
        guard maxSteps > 0 else { throw ValidationError("--max-steps must be positive.") }
        guard (0 ... 1).contains(minConfidence) else { throw ValidationError("--min-confidence must be within 0...1.") }
    }
}

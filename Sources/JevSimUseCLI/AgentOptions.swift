import ArgumentParser
import JevSimUseKit

/// Per-run limits shared by `run` and `session resume`.
struct AgentOptions: ParsableArguments {
    @Option(help: "Maximum number of actions in this run.")
    var maxSteps = 15

    @Option(help: "Hand over when Jev's support for a tap, scroll, or typing is below this (0...1). Taps Jev judges irreversible and Escape need at least 0.6, hardware buttons (leaving the app) 0.85.")
    var minConfidence = ActionPolicy.defaultMinimumSupport

    @Option(help: ArgumentHelp(
        "Offer Jev only these operations, comma-separated; all when omitted.",
        discussion: "Groups: \(OperationGroup.allCases.map(\.rawValue).joined(separator: ", ")). Done and hand-over are always offered.",
        valueName: "groups",
    ))
    var actions: String?

    @Option(help: ArgumentHelp(
        "Cut a step (read, plan, act) off after this many seconds, restart the sim-use daemon, and plan it again; a "
            + "second cut in a row ends the run (exit 3). 0 or off disables it.",
        valueName: "seconds",
    ))
    var stepTimeout = "20"

    /// `--step-timeout` as a duration, or `nil` when it is off.
    var stepTimeoutDuration: Duration? {
        get throws {
            if stepTimeout == "off" {
                return nil
            }
            guard let seconds = Double(stepTimeout), seconds >= 0, seconds.isFinite else {
                throw ValidationError("--step-timeout must be a number of seconds, 0, or off.")
            }
            return seconds == 0 ? nil : .milliseconds(Int(seconds * 1000))
        }
    }

    /// The groups `--actions` names, or all of them.
    var allowedOperations: Set<OperationGroup> {
        get throws {
            guard let actions else { return OperationGroup.all }
            return try Set(actions.split(separator: ",").map { name in
                let name = name.trimmingCharacters(in: .whitespaces)
                guard let group = OperationGroup(rawValue: name) else {
                    let known = OperationGroup.allCases.map(\.rawValue).joined(separator: ", ")
                    throw ValidationError("Unknown --actions group \"\(name)\"; use: \(known).")
                }
                return group
            })
        }
    }

    func validate() throws {
        _ = try allowedOperations
        _ = try stepTimeoutDuration
        guard maxSteps > 0 else { throw ValidationError("--max-steps must be positive.") }
        guard (0 ... 1).contains(minConfidence) else { throw ValidationError("--min-confidence must be within 0...1.") }
    }
}

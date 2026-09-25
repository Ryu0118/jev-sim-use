import ArgumentParser
import JevSimUseKit

/// Per-run limits shared by `run` and `session resume`.
struct AgentOptions: ParsableArguments {
    @Option(help: "Maximum number of actions in this run.")
    var maxSteps = 15

    @Option(help: "Hand over when Jev's support for a tap, scroll, or typing is below this (0...1). Destructive taps need at least 0.6, hardware buttons (leaving the app) 0.85.")
    var minConfidence = ActionPolicy.defaultMinimumSupport

    @Option(help: ArgumentHelp(
        "Offer Jev only these operations, comma-separated; all when omitted.",
        discussion: "Groups: \(OperationGroup.allCases.map(\.rawValue).joined(separator: ", ")). Done and hand-over are always offered.",
        valueName: "groups",
    ))
    var actions: String?

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
        guard maxSteps > 0 else { throw ValidationError("--max-steps must be positive.") }
        guard (0 ... 1).contains(minConfidence) else { throw ValidationError("--min-confidence must be within 0...1.") }
    }
}

import Foundation
import JevSimUseKit

extension SessionRecord {
    /// One line for `session list`.
    var summaryLine: String {
        "\(id)  \(updatedAt.formatted(.iso8601))  \(status)  \(goal)"
    }

    /// The lines `session show` prints: enough for a supervisor to decide what to `tell`.
    var detailLines: [String] {
        var lines = ["Session: \(id) (\(status))", "Goal: \(goal)", "Device: \(deviceID ?? "not connected yet")"]
        lines += texts.isEmpty ? [] : ["Texts: \(texts.map(\.name).joined(separator: ", "))"]
        lines += ["Notes:"] + (notes.isEmpty ? ["  (none)"] : notes.enumerated().map { "  \($0.offset + 1). \($0.element)" })
        lines += ["Runs:"] + runs.enumerated().map { index, run in
            "  \(index + 1). \(run.endedAt.formatted(.iso8601)), \(run.steps) action(s): \(run.outcome)"
        }
        lines += ["Actions:"] + history.map { entry in
            let effect = switch entry.screenChanged {
            case true: ""
            case false: " (screen unchanged)"
            case nil: " (not observed)"
            }
            return "  [\(entry.step)] \(entry.action)\(effect)"
        }
        return lines
    }

    private var status: String {
        runs.isEmpty ? "not run" : "stopped"
    }
}

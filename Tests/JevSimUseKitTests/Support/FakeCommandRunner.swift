import Foundation
@testable import JevSimUseKit
import Synchronization

/// Replays canned outputs by subcommand and records every invocation.
final class FakeCommandRunner: CommandRunning {
    private let outputs: [String: CommandOutput]
    private let calls = Mutex<[[String]]>([])

    var recordedCalls: [[String]] {
        calls.withLock { $0 }
    }

    init(_ outputs: [String: CommandOutput]) {
        self.outputs = outputs
    }

    func run(_: URL, arguments: [String], environment _: [String: String]) async throws -> CommandOutput {
        calls.withLock { $0.append(arguments) }
        return outputs[arguments.first ?? ""] ?? CommandOutput(exitCode: 127, stdout: Data(), stderr: "no fake")
    }
}

extension CommandOutput {
    static func json(_ text: String, exitCode: Int32 = 0) -> CommandOutput {
        CommandOutput(exitCode: exitCode, stdout: Data(text.utf8), stderr: "")
    }
}

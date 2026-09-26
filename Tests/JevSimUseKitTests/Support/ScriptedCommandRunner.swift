import Foundation
@testable import JevSimUseKit
import Synchronization

/// Answers each command through `respond`, which may sleep to stand in for a hung sim-use daemon, and records every
/// invocation with its environment additions.
final class ScriptedCommandRunner: CommandRunning {
    /// One recorded invocation.
    struct Call: Equatable {
        let arguments: [String]
        let environment: [String: String]

        /// Whether the call ran outside the daemon.
        var bypassedDaemon: Bool {
            environment == SimUseContract.noDaemonEnvironment
        }
    }

    private let respond: @Sendable (Call) async throws -> CommandOutput
    private let calls = Mutex<[Call]>([])

    var recordedCalls: [Call] {
        calls.withLock { $0 }
    }

    init(_ respond: @escaping @Sendable (Call) async throws -> CommandOutput) {
        self.respond = respond
    }

    func run(_: URL, arguments: [String], environment: [String: String]) async throws -> CommandOutput {
        let call = Call(arguments: arguments, environment: environment)
        calls.withLock { $0.append(call) }
        return try await respond(call)
    }
}

extension CommandOutput {
    /// A `ui` envelope on `platform` showing `app`, with no elements.
    static func screen(app: String, platform: String = "ios") -> CommandOutput {
        .json(#"{"ok":true,"data":{"platform":"\#(platform)","outline":"App: \#(app)","appLabel":"\#(app)","entries":[]}}"#)
    }

    /// `daemon stop`'s envelope for one daemon.
    static func daemonStop(stopped: Bool) -> CommandOutput {
        .json(#"{"ok":true,"data":{"entries":[{"deviceId":"d","method":"sigterm","pid":1,"stopped":\#(stopped)}]}}"#)
    }
}

import Foundation
@testable import JevSimUseKit
import Testing

/// Checks the installed sim-use against `SimUseContract`. Needs sim-use and a booted device, so it runs only
/// through `mise run contract-test` (which sets `JEV_SIM_USE_CONTRACT=1`).
@Suite(
    "installed sim-use still accepts every name and payload this tool relies on",
    .enabled(if: ProcessInfo.processInfo.environment["JEV_SIM_USE_CONTRACT"] == "1"),
    .serialized,
)
struct SimUseContractTests {
    private let environment = ProcessInfo.processInfo.environment
    private let runner = ProcessCommandRunner()

    private var bootstrap: SimUseBootstrap {
        SimUseBootstrap(locator: ExecutableLocator(environment: environment), runner: runner)
    }

    @Test("every subcommand's help mentions the flags and presets we pass", arguments: SimUseContract.helpExpectations)
    func helpMentions(command: String, mentions: [String]) async throws {
        let executable = try await bootstrap.verifyInstallation().executable
        let output = try await runner.run(executable, arguments: [command, "--help"])
        let help = (String(bytes: output.stdout, encoding: .utf8) ?? "") + output.stderr
        for mention in mentions {
            #expect(help.contains(mention), "`sim-use \(command) --help` no longer mentions \(mention)")
        }
    }

    @Test("devices and ui decode on the booted device")
    func payloadsDecode() async throws {
        let connection = try await bootstrap.connect(
            deviceID: SimUseBootstrap.deviceID(flag: nil, environment: environment),
        )
        let snapshot = try await connection.client.observe().snapshot
        #expect(!snapshot.outline.isEmpty)
        #expect(snapshot.entries != nil)
    }
}

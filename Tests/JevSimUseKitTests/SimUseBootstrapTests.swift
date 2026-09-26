@testable import JevSimUseKit
import Testing

/// The version gate in front of every run: a sim-use too old to produce the output this tool parses stops here
/// instead of failing later on unreadable JSON.
@Suite("sim-use older than the minimum is rejected before any device work")
struct SimUseBootstrapTests {
    @Test("rejects a sim-use older than the minimum")
    func outdated() async throws {
        let installed = try ExecutableLocator(environment: ["PATH": TemporaryPath().withExecutable("sim-use")])
        let bootstrap = SimUseBootstrap(locator: installed, runner: FakeCommandRunner(["--version": .text("0.9.0\n")]))
        let expected = SimUseError.outdated(found: SemanticVersion(0, 9, 0), minimum: SimUseBootstrap.minimumVersion)
        await #expect(throws: expected) {
            try await bootstrap.verifyInstallation()
        }
    }
}

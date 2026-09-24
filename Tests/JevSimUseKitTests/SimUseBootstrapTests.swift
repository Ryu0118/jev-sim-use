import Foundation
@testable import JevSimUseKit
import Testing

struct SimUseBootstrapTests {
    private let installed: ExecutableLocator

    init() throws {
        installed = try ExecutableLocator(environment: ["PATH": TemporaryPath().withExecutable("sim-use")])
    }

    @Test("asks the user to install sim-use when it is not on PATH")
    func notInstalled() async {
        let bootstrap = SimUseBootstrap(
            locator: ExecutableLocator(environment: ["PATH": "/missing/bin"]),
            runner: FakeCommandRunner([:]),
        )
        await #expect(throws: SimUseError.notInstalled(searchedPath: "/missing/bin")) {
            try await bootstrap.verifyInstallation()
        }
        #expect(SimUseError.notInstalled(searchedPath: "").description.contains("brew install lycorp-jp/tap/sim-use"))
    }

    @Test("rejects a sim-use older than the minimum")
    func outdated() async {
        let bootstrap = SimUseBootstrap(locator: installed, runner: FakeCommandRunner(["--version": .text("0.9.0\n")]))
        let expected = SimUseError.outdated(found: SemanticVersion(0, 9, 0), minimum: SimUseBootstrap.minimumVersion)
        await #expect(throws: expected) {
            try await bootstrap.verifyInstallation()
        }
    }

    @Test("pins the only usable device and ignores physical iPhones")
    func pinsSingleDevice() async throws {
        let runner = FakeCommandRunner([
            "--version": .text("v0.14.0\n"),
            "devices": .json(Fixtures.devices(Fixtures.simulator, Fixtures.physicalIPhone)),
        ])
        let client = try await SimUseBootstrap(locator: installed, runner: runner).connect(deviceID: nil)
        #expect(client.device.name == "iPhone 17 Pro")
        #expect(runner.recordedCalls.last == ["devices", "--json"])
    }

    @Test("refuses to guess between several devices")
    func multipleDevices() async {
        let runner = FakeCommandRunner([
            "--version": .text("v0.14.0"),
            "devices": .json(Fixtures.devices(Fixtures.simulator, Fixtures.emulator)),
        ])
        await #expect(throws: SimUseError.self) {
            try await SimUseBootstrap(locator: installed, runner: runner).connect(deviceID: nil)
        }
    }
}

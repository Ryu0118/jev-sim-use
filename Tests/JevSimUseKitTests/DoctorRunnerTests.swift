import Foundation
@testable import JevSimUseKit
import Testing

struct DoctorRunnerTests {
    private let request = DoctorRequest(deviceID: nil, baseURL: nil, model: nil)

    private func runner(_ commands: [String: CommandOutput], path: String?) -> DoctorRunner {
        let environment = ["XDG_CONFIG_HOME": NSTemporaryDirectory()]
        return DoctorRunner(
            bootstrap: SimUseBootstrap(
                locator: ExecutableLocator(environment: path.map { ["PATH": $0] } ?? [:]),
                runner: FakeCommandRunner(commands),
            ),
            configStore: UserConfigStore(environment: environment),
            environment: environment,
        )
    }

    @Test("reads the screen once when sim-use and the device are ready")
    func healthyDevice() async throws {
        let report = try await runner([
            "--version": .text("v0.14.0"),
            "devices": .json(Fixtures.devices(Fixtures.simulator)),
            "ui": .json(#"{"ok":true,"data":{"platform":"ios","outline":"App","entries":[]}}"#),
        ], path: TemporaryPath().withExecutable("sim-use")).run(request)
        #expect(report.checks[1].status == .passed(
            "iPhone 17 Pro (B34F0000-0000-0000-0000-000000000001); screen readable, 0 elements",
        ))
        #expect(!report.isHealthy)
    }

    @Test("skips the device check when sim-use is missing")
    func missingSimUse() async {
        let report = await runner([:], path: nil).run(request)
        #expect(report.checks.map(\.name) == ["sim-use", "device", "jev"])
        #expect(report.checks[1].status == .skipped("sim-use is not ready"))
    }
}

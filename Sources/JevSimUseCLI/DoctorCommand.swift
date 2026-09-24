import ArgumentParser
import JevSimUseKit

struct DoctorCommand: ContextualCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check that sim-use, a device, and Jev settings are ready (reads the screen once; no Jev call).",
    )

    @OptionGroup var connection: ConnectionOptions

    func run(context: CLIContext) async throws {
        let runner = DoctorRunner(
            bootstrap: SimUseBootstrap(locator: ExecutableLocator(environment: context.environment)),
            configStore: UserConfigStore(environment: context.environment),
            environment: context.environment,
        )
        let report = await runner.run(
            DoctorRequest(deviceID: connection.device, baseURL: connection.baseURL, model: connection.model),
        )
        for check in report.checks {
            context.output.standardOutput(Self.line(for: check))
        }
        guard report.isHealthy else { throw ExitCode.failure }
    }

    static func line(for check: DoctorCheck) -> String {
        switch check.status {
        case let .passed(detail): "✓ \(check.name): \(detail)"
        case let .failed(reason): "✗ \(check.name): \(reason)"
        case let .skipped(reason): "– \(check.name): skipped, \(reason)"
        }
    }
}

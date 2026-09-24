import ArgumentParser
import SimJevUseKit

struct DoctorCommand: ContextualCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check that sim-use, a device, and Jev settings are ready.",
    )

    @OptionGroup var connection: ConnectionOptions

    func run(context: CLIContext) async throws {
        let bootstrap = SimUseBootstrap(locator: ExecutableLocator(environment: context.environment))
        let simUseReady = await check("sim-use", context) {
            let (path, version) = try await bootstrap.verifyInstallation()
            return "\(version) at \(path.path(percentEncoded: false))"
        }
        let deviceReady = simUseReady ? await check("device", context) {
            let device = try await bootstrap.connect(deviceID: connection.resolvedDevice(environment: context.environment)).device
            return "\(device.name) (\(device.deviceId))"
        } : false
        let jevReady = await check("jev", context) {
            let settings = try connection.jevSettings(environment: context.environment)
            return "\(settings.model) at \(settings.endpoint), API key set"
        }
        guard simUseReady, deviceReady, jevReady else { throw ExitCode.failure }
    }

    private func check(_ name: String, _ context: CLIContext, _ body: () async throws -> String) async -> Bool {
        do {
            try await context.output.standardOutput("✓ \(name): \(body())")
            return true
        } catch {
            context.output.standardOutput("✗ \(name): \(error)")
            return false
        }
    }
}

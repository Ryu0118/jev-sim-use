import ArgumentParser
import SimJevUseKit

struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check that sim-use, a device, and Jev settings are ready.",
    )

    @Option(help: "sim-use device id to check.")
    var device: String?

    @OptionGroup var jev: JevOptions

    func run() async throws {
        let bootstrap = SimUseBootstrap()
        let simUseReady = await check("sim-use") {
            let (path, version) = try await bootstrap.verifyInstallation()
            return "\(version) at \(path.path(percentEncoded: false))"
        }
        let deviceReady = simUseReady ? await check("device") {
            let device = try await bootstrap.connect(deviceID: device).device
            return "\(device.name) (\(device.deviceId))"
        } : false
        let jevReady = await check("jev") {
            let settings = try JevSettings.resolve(endpointFlag: jev.endpoint, modelFlag: jev.model)
            return "\(settings.model) at \(settings.endpoint), API key set"
        }
        guard simUseReady, deviceReady, jevReady else { throw ExitCode.failure }
    }

    private func check(_ name: String, _ body: () async throws -> String) async -> Bool {
        do {
            try await print("✓ \(name): \(body())")
            return true
        } catch {
            print("✗ \(name): \(error)")
            return false
        }
    }
}

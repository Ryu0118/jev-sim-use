import Foundation

/// Finds `sim-use`, checks its version, and pins a device.
package struct SimUseBootstrap: Sendable {
    /// The oldest sim-use whose output this tool parses (`kind` in `devices`, `--no-raw`).
    package static let minimumVersion = SemanticVersion(0, 14, 0)

    private let locator: ExecutableLocator
    private let runner: any CommandRunning

    /// Creates a bootstrap that finds sim-use with `locator`.
    package init(
        locator: ExecutableLocator,
        runner: any CommandRunning = ProcessCommandRunner(),
    ) {
        self.locator = locator
        self.runner = runner
    }

    /// Locates sim-use and verifies it is new enough. Returns its path and version.
    package func verifyInstallation() async throws -> (executable: URL, version: SemanticVersion) {
        guard let executable = locator.locate("sim-use") else {
            throw SimUseError.notInstalled(searchedPath: locator.searchedPath)
        }
        let output = try await runner.run(executable, arguments: ["--version"])
        let text = (String(bytes: output.stdout, encoding: .utf8) ?? "") + output.stderr
        guard let version = SemanticVersion(parsing: text) else {
            throw SimUseError.unreadableVersion(output: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard version >= Self.minimumVersion else {
            throw SimUseError.outdated(found: version, minimum: Self.minimumVersion)
        }
        return (executable, version)
    }

    /// Verifies the installation and pins `deviceID`, or the only usable device when `nil`.
    package func connect(deviceID: String?) async throws -> SimUseClient {
        let (executable, _) = try await verifyInstallation()
        let invoker = SimUseInvoker(executable: executable, runner: runner)
        let devices = try await invoker.invoke(["devices"], as: DeviceListPayload.self).data?.devices ?? []
        let device = try DeviceSelection.select(deviceID, from: devices)
        return SimUseClient(device: device, invoker: invoker)
    }
}

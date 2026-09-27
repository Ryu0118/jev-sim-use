import Foundation

/// Opens the live watcher on a simulator's display, through the CoreSimulator of the selected Xcode.
package struct SimulatorScreenWatchOpener: ScreenWatchOpening {
    /// Set to `0` to read the screen by polling as before, to compare the two on one binary.
    package static let switchVariable = "JEV_SIM_USE_SCREEN_WATCH"
    /// Selects an Xcode for this process, ahead of `xcode-select -p`.
    static let developerDirectoryVariable = "DEVELOPER_DIR"
    static let xcodeSelect = URL(filePath: "/usr/bin/xcode-select")

    private let environment: [String: String]
    private let runner: any CommandRunning

    /// Creates an opener that reads the switch and the developer directory from `environment`.
    package init(environment: [String: String], runner: some CommandRunning = SubprocessCommandRunner()) {
        self.environment = environment
        self.runner = runner
    }

    /// A watcher on the booted simulator `simulatorID`'s main display.
    package func open(simulatorID: String) async throws(ScreenWatchError) -> any ClosableScreenWatcher {
        guard environment[Self.switchVariable] != "0" else { throw .disabled }
        let locator = try await CoreSimulatorLocator(developerDirectory: developerDirectory())
        return try SimulatorScreenWatcher(display: locator.mainDisplay(ofDevice: simulatorID))
    }

    private func developerDirectory() async throws(ScreenWatchError) -> String {
        if let directory = environment[Self.developerDirectoryVariable], !directory.isEmpty {
            return directory
        }
        // Any failure to run it means the same as an empty answer: no Xcode to watch with.
        let output = try? await runner.run(Self.xcodeSelect, arguments: ["-p"])
        let directory = output.flatMap { String(bytes: $0.stdout, encoding: .utf8) }?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard output?.exitCode == 0, !directory.isEmpty else { throw .developerDirectoryUnknown }
        return directory
    }
}

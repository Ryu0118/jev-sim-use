/// Drives one device through the `sim-use` CLI.
///
/// Every call passes the same `--device`, because `tap @N` resolves against the
/// outline sim-use cached for that device on the previous `ui` call.
public struct SimUseClient: DeviceDriving {
    /// The device every command targets.
    public let device: SimUseDevice
    private let invoker: SimUseInvoker

    init(device: SimUseDevice, invoker: SimUseInvoker) {
        self.device = device
        self.invoker = invoker
    }

    /// Runs `sim-use ui --no-raw`, which also refreshes the alias cache `tap` uses.
    public func observe() async throws -> ScreenObservation {
        let envelope = try await invoker.invoke(["ui", "--no-raw"] + deviceArguments, as: UISnapshot.self)
        guard let snapshot = envelope.data else {
            throw SimUseError.malformedOutput(arguments: ["ui"], detail: "the envelope has no data")
        }
        return ScreenObservation(snapshot: snapshot, disappearedApps: envelope.process?.disappearedBundleIDs ?? [])
    }

    /// Runs `sim-use tap @alias`.
    public func tap(alias: Int) async throws -> [String] {
        try await run(["tap", "@\(alias)"])
    }

    /// Runs the sim-use gesture or button for `action`.
    public func perform(_ action: SimUseDeviceAction, platform: String) async throws -> [String] {
        try await run(action.arguments(platform: platform))
    }

    /// Runs `sim-use paste`, which accepts Unicode on iOS where `type` does not.
    public func paste(_ text: String) async throws -> [String] {
        try await run(["paste", text])
    }

    private var deviceArguments: [String] {
        ["--device", device.deviceId]
    }

    private func run(_ arguments: [String]) async throws -> [String] {
        let envelope = try await invoker.invoke(arguments + deviceArguments, as: EmptyPayload.self)
        return envelope.process?.disappearedBundleIDs ?? []
    }
}

/// Drives one device through the `sim-use` CLI.
///
/// Every call passes the same `--device`, because `tap @N` resolves against the
/// outline sim-use cached for that device on the previous `ui` call.
package struct SimUseClient: DeviceDriving {
    /// The device every command targets.
    package let device: SimUseDevice
    private let invoker: SimUseInvoker

    init(device: SimUseDevice, invoker: SimUseInvoker) {
        self.device = device
        self.invoker = invoker
    }

    /// Runs `sim-use ui --no-raw`, which also refreshes the alias cache `tap` uses.
    package func observe() async throws -> ScreenObservation {
        let envelope = try await invoker.invoke([SimUseContract.Command.ui, SimUseContract.noRawFlag] + deviceArguments, as: UISnapshot.self)
        guard let snapshot = envelope.data else {
            throw SimUseError.malformedOutput(arguments: [SimUseContract.Command.ui], detail: "the envelope has no data")
        }
        return ScreenObservation(snapshot: snapshot, disappearedApps: envelope.process?.disappearedBundleIDs ?? [])
    }

    /// Runs `sim-use tap @alias`. An iOS switch ignores that instant tap at the row's centre, so a toggle is tapped
    /// on the switch itself, at the row's trailing edge, with a short hold; an element whose centre an overlay covers
    /// is tapped at a point the overlay leaves clear.
    package func tap(alias: Int, on snapshot: UISnapshot) async throws -> [String] {
        guard let entry = snapshot.entry(alias: alias) else { return try await run([SimUseContract.Command.tap, "@\(alias)"]) }
        guard snapshot.platform == SimUseContract.Platform.ios, entry.isToggle, let frame = entry.frame else {
            guard let point = snapshot.uncoveredPoint(of: entry) else {
                return try await run([SimUseContract.Command.tap, "@\(alias)"])
            }
            return try await run([
                SimUseContract.Command.tap, SimUseContract.Tap.x, "\(point.x)", SimUseContract.Tap.y, "\(point.y)",
            ])
        }
        // A UISwitch is 51 pt wide and sits at the trailing edge of its row.
        let x = max(frame.center.x, frame.x + frame.width - 26)
        return try await run([
            SimUseContract.Command.tap, SimUseContract.Tap.x, "\(x)", SimUseContract.Tap.y, "\(frame.center.y)",
            SimUseContract.Tap.duration, SimUseContract.Tap.switchHoldSeconds,
        ])
    }

    /// Runs `long-press`, `swipe`, or a two-finger preset on the element's frame.
    package func perform(_ gesture: ElementGesture, alias: Int, on snapshot: UISnapshot) async throws -> [String] {
        guard let frame = snapshot.entry(alias: alias)?.frame else {
            throw SimUseError.malformedOutput(
                arguments: [SimUseContract.Command.ui], detail: "element @\(alias) has no frame to aim \(gesture.rawValue) at",
            )
        }
        return try await run(gesture.arguments(alias: alias, frame: frame))
    }

    /// Runs the sim-use gesture or button for `action`.
    package func perform(_ action: SimUseDeviceAction, platform: String) async throws -> [String] {
        try await run(action.arguments(platform: platform))
    }

    /// Runs `sim-use paste`, which accepts Unicode on iOS where `type` does not.
    package func paste(_ text: String) async throws -> [String] {
        try await run([SimUseContract.Command.paste], operands: [text])
    }

    private var deviceArguments: [String] {
        [SimUseContract.deviceFlag, device.deviceId]
    }

    private func run(_ arguments: [String], operands: [String] = []) async throws -> [String] {
        let envelope = try await invoker.invoke(
            arguments + deviceArguments, operands: operands, as: EmptyPayload.self,
        )
        return envelope.process?.disappearedBundleIDs ?? []
    }
}

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

    /// Runs `sim-use ui`, which also refreshes the alias cache `tap` uses. The raw tree is kept because only it carries
    /// iOS accessibility hints; it tripled the payload (5 to 16 KB) without slowing the read.
    package func observe() async throws -> ScreenObservation {
        let envelope = try await invoker.invoke([SimUseContract.Command.ui] + deviceArguments, as: UISnapshot.self)
        guard let snapshot = envelope.data else {
            throw SimUseError.malformedOutput(arguments: [SimUseContract.Command.ui], detail: "the envelope has no data")
        }
        return ScreenObservation(snapshot: snapshot, disappearedApps: envelope.process?.disappearedBundleIDs ?? [])
    }

    /// Runs `sim-use tap @alias`. An iOS switch ignores that instant tap at the row's centre, so a toggle is tapped on
    /// the switch itself, at the row's trailing edge, with a short hold. A value row's control (a
    /// SwiftUI ColorPicker's colour well) is tapped the same way: the row's centre did nothing there, its trailing edge
    /// opened it.
    package func tap(alias: Int, on snapshot: UISnapshot) async throws -> [String] {
        if let entry = snapshot.entry(alias: alias), let scroll = snapshot.revealingScroll(for: entry) {
            return try await reveal(entry, by: scroll, in: snapshot)
        }
        return try await tapInPlace(alias: alias, on: snapshot)
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
    ///
    /// On iOS the paste is a Cmd+V key event, which the simulator drops without a connected hardware keyboard while
    /// sim-use still reports success; the software keyboard being up after the field's tap means exactly that. The
    /// edit-menu path (`--via-menu`) did not help: its Paste item never appeared in Reminders or Safari.
    package func paste(_ text: String) async throws -> [String] {
        if device.platform == SimUseContract.Platform.ios, try await softKeyboardIsVisible() {
            throw SimUseError.hardwareKeyboardRequired
        }
        return try await run([SimUseContract.Command.paste], operands: [text])
    }

    /// Taps `entry` by coordinates: a switch or value row on its trailing control, anything else at its centre.
    package func tapWhereShown(_ entry: UIEntry, on snapshot: UISnapshot) async throws -> [String] {
        guard let frame = entry.frame else { return try await tapInPlace(alias: entry.aliases.alias, on: snapshot) }
        return try await tap(point(on: entry, frame: frame, platform: snapshot.platform), on: snapshot.platform)
    }

    private func tapInPlace(alias: Int, on snapshot: UISnapshot) async throws -> [String] {
        guard snapshot.platform == SimUseContract.Platform.ios,
              let entry = snapshot.entry(alias: alias), entry.isToggle || entry.isValueRow, let frame = entry.frame
        else { return try await tap([SimUseContract.Command.tap, "@\(alias)"], on: snapshot.platform) }
        return try await tap(point(on: entry, frame: frame, platform: snapshot.platform), on: snapshot.platform)
    }

    /// The `tap` arguments for a coordinate tap on `entry`. On iOS a switch (51 pt) or colour well (28 pt) sits at the
    /// row's trailing edge, and both answered only a short hold there.
    private func point(on entry: UIEntry, frame: ElementFrame, platform: String) -> [String] {
        let trailing = platform == SimUseContract.Platform.ios && (entry.isToggle || entry.isValueRow)
        let x = trailing ? max(frame.center.x, frame.x + frame.width - (entry.isToggle ? 26 : 18)) : frame.center.x
        let hold = trailing ? [SimUseContract.Tap.duration, SimUseContract.Tap.switchHoldSeconds] : []
        return [SimUseContract.Command.tap, SimUseContract.Tap.x, "\(x)", SimUseContract.Tap.y, "\(frame.center.y)"] + hold
    }

    /// Scrolls `entry` into reach, reads the screen until the scroll has stopped (a tap on a list still coasting
    /// only stopped it, and a switch stayed as it was), and taps the same element there the usual way, so a switch is
    /// still tapped on its trailing edge. The new reading also refreshes the cached aliases the scroll made stale.
    /// When the element is not found, or is still out of reach, it throws `targetNotRevealed` so the run records the
    /// scroll alone (a floating button that hid itself as the list moved had been recorded as tapped).
    private func reveal(_ entry: UIEntry, by scroll: SimUseDeviceAction, in snapshot: UISnapshot) async throws -> [String] {
        var disappeared = try await perform(scroll, platform: snapshot.platform)
        var fresh = try await observe()
        disappeared += fresh.disappearedApps
        for _ in 0 ..< Self.revealSettleReads {
            let next = try await observe()
            disappeared += next.disappearedApps
            let stopped = next.snapshot.layout == fresh.snapshot.layout
            fresh = next
            if stopped {
                break
            }
        }
        let origin = entry.frame?.center.y ?? 0
        let match = (fresh.snapshot.entries ?? [])
            .filter { $0.role == entry.role && $0.label == entry.label && $0.uniqueId == entry.uniqueId }
            .filter { fresh.snapshot.revealingScroll(for: $0) == nil }
            .min { abs(($0.frame?.center.y ?? 0) - origin) < abs(($1.frame?.center.y ?? 0) - origin) }
        guard let match else { throw SimUseError.targetNotRevealed(scroll: scroll, disappearedApps: disappeared) }
        return try await disappeared + tapInPlace(alias: match.aliases.alias, on: fresh.snapshot)
    }

    /// Extra readings allowed while a revealing scroll still moves the screen.
    static let revealSettleReads = 3

    /// Runs a `tap` command, on iOS outside the daemon (see `SimUseContract.noDaemonEnvironment`).
    private func tap(_ arguments: [String], on platform: String) async throws -> [String] {
        try await run(arguments, environment: platform == SimUseContract.Platform.ios ? SimUseContract.noDaemonEnvironment : [:])
    }

    private func softKeyboardIsVisible() async throws -> Bool {
        struct KeyboardState: Decodable, Sendable {
            let visible: Bool?
        }
        let envelope = try await invoker.invoke(
            [SimUseContract.Command.keyboardState] + deviceArguments, as: KeyboardState.self,
        )
        return envelope.data?.visible ?? false
    }

    private var deviceArguments: [String] {
        [SimUseContract.deviceFlag, device.deviceId]
    }

    private func run(
        _ arguments: [String], operands: [String] = [], environment: [String: String] = [:],
    ) async throws -> [String] {
        let envelope = try await invoker.invoke(
            arguments + deviceArguments, operands: operands, environment: environment, as: EmptyPayload.self,
        )
        return envelope.process?.disappearedBundleIDs ?? []
    }
}

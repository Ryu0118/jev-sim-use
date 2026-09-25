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
    /// on the switch itself, at the row's trailing edge, with a short hold.
    package func tap(alias: Int, on snapshot: UISnapshot) async throws -> [String] {
        if let entry = snapshot.entry(alias: alias), let cover = snapshot.cover(of: entry) {
            return try await revealThenTap(entry, under: cover, in: snapshot)
        }
        guard snapshot.platform == SimUseContract.Platform.ios,
              let entry = snapshot.entry(alias: alias), entry.isToggle, let frame = entry.frame
        else { return try await run([SimUseContract.Command.tap, "@\(alias)"]) }
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

    /// Scrolls a covered element out from under its overlay, then taps it by a fresh selector: the scroll made the
    /// cached alias stale. Falls back to the alias when the element has neither an identifier nor a label.
    private func revealThenTap(_ entry: UIEntry, under cover: UIEntry, in snapshot: UISnapshot) async throws -> [String] {
        // An overlay in the lower half (a bottom search bar) needs the row moved up, which reveals content below.
        // Comparing the overlay with the row itself flipped when the row sat a few points lower.
        let screenHeight = (snapshot.entries ?? []).compactMap(\.frame).map { $0.y + $0.height }.max() ?? 0
        let overlayIsLower = (cover.frame?.center.y ?? 0) >= screenHeight / 2
        var disappeared = try await perform(
            overlayIsLower ? .revealContentBelow : .revealContentAbove, platform: snapshot.platform,
        )
        let selector: [String]? = if let id = entry.uniqueId {
            [SimUseContract.Tap.id, id]
        } else if !entry.label.isEmpty {
            [SimUseContract.Tap.label, entry.label]
        } else {
            nil
        }
        disappeared += try await run([SimUseContract.Command.tap] + (selector ?? ["@\(entry.aliases.alias)"]))
        return disappeared
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

    private func run(_ arguments: [String], operands: [String] = []) async throws -> [String] {
        let envelope = try await invoker.invoke(
            arguments + deviceArguments, operands: operands, as: EmptyPayload.self,
        )
        return envelope.process?.disappearedBundleIDs ?? []
    }
}

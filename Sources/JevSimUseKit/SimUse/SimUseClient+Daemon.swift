/// Deadlines on sim-use calls and replacing a hung daemon: the only place that stops daemons.
///
/// Every iOS call gets a deadline from `CallBaselines`: `factor` times the median of this device's recent calls of its
/// kind, never below the floor, with an action's own duration added. A call past it is cancelled, which kills the
/// `sim-use` process, and the device's daemon is stopped, once per hang. A read is then taken once outside the daemon,
/// under its own deadline; an action is never sent again, since it may have landed, and the loop reads and plans
/// again. A call that does not answer after that throws `callTimedOut`, which the loop counts as a hang incident. Only
/// the deadline triggers this: an error envelope comes back within a quarter second and is thrown as it is.
extension SimUseClient {
    /// A read through the daemon, or, past its deadline, one outside it after the daemon was stopped.
    func guardedRead() async throws -> ScreenObservation {
        let deadline = timing.deadline(for: .read)
        let clock = ContinuousClock()
        let start = clock.now
        if let reading = try await within(deadline, { try await read() }) {
            timing.record(.read, clock.now - start)
            timing.lastApp = reading.snapshot.appLabel
            return reading
        }
        let lastApp = timing.lastApp
        let stopped = await stopDaemon()
        report(DaemonRecovery(deviceID: device.deviceId, waited: deadline, daemonStopped: stopped))
        guard var reading = try await within(deadline, { try await read(environment: SimUseContract.noDaemonEnvironment) })
        else {
            throw SimUseError.callTimedOut(command: SimUseContract.Command.ui, seconds: deadline / .seconds(1), daemonStopped: stopped)
        }
        timing.lastApp = reading.snapshot.appLabel
        // The daemon reports an app that disappeared on its next command, and that report went with the stopped
        // daemon; a read outside it reports none. An app no longer on screen may have crashed, so it counts as gone.
        if let lastApp, lastApp != reading.snapshot.appLabel {
            reading.disappearedApps.append("\(lastApp), gone from the screen when a hung sim-use daemon was replaced")
        }
        return reading
    }

    /// Runs `body`, the sim-use call `arguments`, within the deadline for `kind`: past it, the call is killed, the
    /// daemon stopped, and `callTimedOut` thrown. Android calls run without one.
    func guarded<T: Sendable>(_ kind: CallKind, _ arguments: [String], _ body: @escaping @Sendable () async throws -> T) async throws -> T {
        guard device.platform == SimUseContract.Platform.ios else { return try await body() }
        let intrinsic = kind == .action ? CallTimingPolicy.intrinsicDuration(of: arguments) : .zero
        let deadline = timing.deadline(for: kind, intrinsic: intrinsic)
        let clock = ContinuousClock()
        let start = clock.now
        if let result = try await within(deadline, body) {
            timing.record(kind, max(.zero, clock.now - start - intrinsic))
            return result
        }
        let stopped = await stopDaemon()
        throw SimUseError.callTimedOut(command: arguments.first ?? "", seconds: deadline / .seconds(1), daemonStopped: stopped)
    }

    /// `body`'s result, or `nil` when `deadline` passed first; the call is then cancelled, which kills the `sim-use`
    /// process. Cancelling the caller is not a timeout: it throws as usual.
    private func within<T: Sendable>(_ deadline: Duration, _ body: @escaping @Sendable () async throws -> T) async throws -> T? {
        try await withThrowingTaskGroup(of: T?.self) { group in
            group.addTask { try await body() }
            group.addTask {
                try await Task.sleep(for: deadline)
                return nil
            }
            defer { group.cancelAll() }
            return try await group.next() ?? nil
        }
    }

    /// The deadlines this device's calls get now; none off iOS, whose calls run without one.
    package func callDeadlines() -> CallDeadlines? {
        device.platform == SimUseContract.Platform.ios ? timing.deadlines : nil
    }

    /// Runs `daemon stop` for this device and returns whether the daemon is gone. A daemon that stopped answering
    /// altogether ignored the stop and reported `stopped: false`; that is reported rather than thrown.
    package func stopDaemon() async -> Bool {
        struct StopPayload: Decodable, Sendable {
            struct Entry: Decodable, Sendable {
                let stopped: Bool?
            }

            let entries: [Entry]?
        }
        let envelope = try? await invoker.invoke(
            [SimUseContract.Command.daemon, SimUseContract.Daemon.stop] + deviceArguments
                + [SimUseContract.Daemon.timeout, SimUseContract.Daemon.stopSeconds],
            as: StopPayload.self,
        )
        return (envelope?.data?.entries ?? []).allSatisfy { $0.stopped == true } && envelope != nil
    }
}

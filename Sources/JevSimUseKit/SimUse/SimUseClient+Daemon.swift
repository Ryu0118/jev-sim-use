/// Replacing a hung sim-use daemon; the policy is `SimUseDaemonWatchdog`'s.
extension SimUseClient {
    /// Reads through the daemon within the watchdog's deadline. Past it, the read is cancelled, the daemon stopped, and
    /// the screen read outside it. Only the deadline triggers this: an error envelope, such as a device that is gone,
    /// comes back within a quarter second and is thrown as it is, and so is any failure of the read outside the daemon.
    func watchedRead() async throws -> ScreenObservation {
        if let reading = try await read(within: watchdog.deadline) {
            watchdog.noteReading(of: reading.snapshot.appLabel)
            return reading
        }
        guard let (lastApp, left) = watchdog.claimRecovery() else {
            throw SimUseError.readTimedOut(deviceID: device.deviceId, seconds: watchdog.deadline / .seconds(1))
        }
        let stopped = try await stopDaemon()
        var reading = try await read(environment: SimUseContract.noDaemonEnvironment)
        watchdog.noteReading(of: reading.snapshot.appLabel)
        // The daemon reports an app that disappeared on its next command, and that report went with the stopped
        // daemon; a read outside it reports none. An app no longer on screen may have crashed, so it counts as gone.
        if let lastApp, lastApp != reading.snapshot.appLabel {
            reading.disappearedApps.append("\(lastApp), gone from the screen when a hung sim-use daemon was replaced")
        }
        watchdog.recovered(DaemonRecovery(deviceID: device.deviceId, waited: watchdog.deadline, daemonStopped: stopped, left: left))
        return reading
    }

    /// A read through the daemon, or `nil` when `deadline` passed first; the read is then cancelled, which kills the
    /// `sim-use` process. Cancelling the caller is not a timeout: it throws as usual.
    private func read(within deadline: Duration) async throws -> ScreenObservation? {
        try await withThrowingTaskGroup(of: ScreenObservation?.self) { group in
            group.addTask { try await read() }
            group.addTask {
                try await Task.sleep(for: deadline)
                return nil
            }
            defer { group.cancelAll() }
            return try await group.next() ?? nil
        }
    }

    /// Runs `daemon stop` for this device and returns whether the daemon is gone. A daemon that stopped answering
    /// altogether ignored the stop and reported `stopped: false`; a failed stop still lets the read outside the daemon
    /// go ahead, so it is reported rather than thrown.
    private func stopDaemon() async throws -> Bool {
        struct StopPayload: Decodable, Sendable {
            struct Entry: Decodable, Sendable {
                let stopped: Bool?
            }

            let entries: [Entry]?
        }
        do {
            let envelope = try await invoker.invoke(
                [SimUseContract.Command.daemon, SimUseContract.Daemon.stop] + deviceArguments
                    + [SimUseContract.Daemon.timeout, SimUseContract.Daemon.stopSeconds],
                as: StopPayload.self,
            )
            return (envelope.data?.entries ?? []).allSatisfy { $0.stopped == true }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return false
        }
    }
}

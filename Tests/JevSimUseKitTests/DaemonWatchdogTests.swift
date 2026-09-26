import Foundation
@testable import JevSimUseKit
import Synchronization
import Testing

/// How a hung sim-use daemon can be mishandled, listed before the watchdog was written. A hung daemon made `ui` take
/// about 10 s, a fresh one hung again within a minute, and a stopped daemon process blocked a read for minutes; the E2E
/// hangs none on purpose, so every recovery path is here.
@Suite("A hung sim-use daemon is replaced a bounded number of times without hiding a crash or a real failure")
struct DaemonWatchdogTests {
    private static let deadline: Duration = .milliseconds(100)
    private static let cap: Duration = .milliseconds(600)
    /// Longer than the deadline, shorter than the cap: a natural hang, which answers in the end.
    private static let slow: Duration = .milliseconds(300)
    private static let hang: Duration = .seconds(30)

    private static func client(
        _ runner: ScriptedCommandRunner, device: String = Fixtures.simulator, reports: Reports = Reports(),
    ) -> SimUseClient {
        SimUseClient(
            device: Fixtures.device(device),
            invoker: SimUseInvoker(executable: URL(filePath: "/sim-use"), runner: runner),
            watchdog: SimUseDaemonWatchdog(deadline: deadline, cap: cap, report: { reports.append($0) }),
        )
    }

    /// Daemon reads whose index is in `hanging` hang, the others show `app`; reads outside the daemon show `reread`.
    private static func runner(
        hanging: Set<Int>, for delay: Duration = hang, app: String = "A", reread: String = "A",
        stop: CommandOutput = .daemonStop(stopped: true),
    ) -> ScriptedCommandRunner {
        let daemonReads = Mutex(0)
        return ScriptedCommandRunner { call in
            if call.arguments.first == SimUseContract.Command.daemon {
                return stop
            }
            if call.bypassedDaemon {
                return .screen(app: reread)
            }
            let index = daemonReads.withLock { reads in
                defer { reads += 1 }
                return reads
            }
            if hanging.contains(index) {
                try await Task.sleep(for: delay)
            }
            return .screen(app: app)
        }
    }

    @Test("leaves a read that answers in time alone: no stop, no warning")
    func fastRead() async throws {
        let reports = Reports()
        let runner = Self.runner(hanging: [])
        _ = try await Self.client(runner, reports: reports).observe()
        #expect(runner.recordedCalls.map(\.arguments.first) == ["ui"])
        #expect(reports.all.isEmpty)
    }

    @Test("stops the hung daemon for this device only, reads again outside it, and reports it once")
    func recovers() async throws {
        let reports = Reports()
        let runner = Self.runner(hanging: [0])
        let reading = try await Self.client(runner, reports: reports).observe()
        let calls = runner.recordedCalls
        #expect(calls.count == 3)
        #expect(calls[1].arguments == ["daemon", "stop", "--device", "B34F0000-0000-0000-0000-000000000001", "--timeout", "1", "--json"])
        #expect(calls[2].arguments.first == "ui" && calls[2].bypassedDaemon)
        #expect(reading.snapshot.appLabel == "A")
        #expect(reports.all.map(\.daemonStopped) == [true])
    }

    @Test("goes back to the daemon after a recovery, since the next read starts a fresh one")
    func returnsToDaemon() async throws {
        let runner = Self.runner(hanging: [0])
        let client = Self.client(runner)
        _ = try await client.observe()
        _ = try await client.observe()
        #expect(runner.recordedCalls.last.map { $0.arguments.first == "ui" && !$0.bypassedDaemon } == true)
    }

    @Test("replaces the daemon at most twice per run, then waits slow reads out instead of failing a run that works today")
    func boundedRecoveries() async throws {
        let reports = Reports()
        let runner = Self.runner(hanging: [0, 1, 2, 3], for: Self.slow)
        let client = Self.client(runner, reports: reports)
        for _ in 0 ..< 4 {
            #expect(try await client.observe().snapshot.appLabel == "A")
        }
        #expect(runner.recordedCalls.count { $0.arguments.first == "daemon" } == 2)
        #expect(reports.all.map(\.left) == [1, 0])
        #expect(reports.all.last?.description.contains("waited out") == true)
    }

    @Test("fails naming the commands that fix it only when a read outlasts the cap after the allowance is spent")
    func frozenDaemon() async throws {
        let client = Self.client(Self.runner(hanging: [0, 1, 2]))
        _ = try await client.observe()
        _ = try await client.observe()
        await #expect(throws: SimUseError.readTimedOut(deviceID: "B34F0000-0000-0000-0000-000000000001", seconds: 0.6)) {
            try await client.observe()
        }
        let message = SimUseError.readTimedOut(deviceID: "X", seconds: 30).description
        #expect(message.contains("jev-sim-use exec daemon status") && message.contains("exec daemon stop --device X"))
    }

    @Test("still reads outside the daemon when the daemon could not be stopped, and says so", arguments: [
        CommandOutput.daemonStop(stopped: false),
        .json(#"{"ok":false,"error":"no permission"}"#, exitCode: 1),
    ])
    func stopFails(stop: CommandOutput) async throws {
        let reports = Reports()
        let runner = Self.runner(hanging: [0], stop: stop)
        let reading = try await Self.client(runner, reports: reports).observe()
        #expect(reading.snapshot.appLabel == "A")
        #expect(reports.all.map(\.daemonStopped) == [false])
    }

    @Test("reports an app that left the screen across the restart as gone, since the daemon's crash report went with it")
    func appChangedAcrossRestart() async throws {
        let client = Self.client(Self.runner(hanging: [1], reread: "Home"))
        #expect(try await client.observe().disappearedApps.isEmpty)
        let recovered = try await client.observe()
        #expect(recovered.disappearedApps.count == 1)
        #expect(recovered.disappearedApps.first?.hasPrefix("A") == true)
    }

    @Test("keeps the same app across the restart as no disappearance")
    func sameAppAcrossRestart() async throws {
        let client = Self.client(Self.runner(hanging: [1]))
        _ = try await client.observe()
        #expect(try await client.observe().disappearedApps.isEmpty)
    }

    @Test("surfaces a failing read outside the daemon unchanged, as a missing device does today")
    func rereadFails() async throws {
        let failure = CommandOutput.json(#"{"ok":false,"error":"Simulator not found"}"#, exitCode: 1)
        let runner = ScriptedCommandRunner { call in
            if call.arguments.first == SimUseContract.Command.daemon {
                return .daemonStop(stopped: true)
            }
            if call.bypassedDaemon {
                return failure
            }
            try await Task.sleep(for: Self.hang)
            return .screen(app: "A")
        }
        await #expect(throws: SimUseError.commandFailed(
            arguments: ["ui", "--device", "B34F0000-0000-0000-0000-000000000001"], message: "Simulator not found", hint: nil,
        )) { try await Self.client(runner).observe() }
    }

    @Test("fails fast on an error envelope from the daemon without replacing it")
    func errorEnvelopeIsNotAHang() async throws {
        let runner = ScriptedCommandRunner { _ in .json(#"{"ok":false,"error":"not booted"}"#, exitCode: 1) }
        await #expect(throws: SimUseError.self) { try await Self.client(runner).observe() }
        #expect(runner.recordedCalls.count == 1)
    }

    @Test("does not take a cancelled read, such as a confirming read dropped after a planning error, for a hang")
    func cancellationIsNotAHang() async throws {
        let runner = Self.runner(hanging: [0])
        let client = Self.client(runner)
        let read = Task { try await client.observe() }
        try await Task.sleep(for: .milliseconds(20))
        read.cancel()
        _ = await read.result
        #expect(runner.recordedCalls.map(\.arguments.first) == ["ui"])
    }

    @Test("leaves Android reads without a deadline: their normal time was never measured")
    func androidHasNoDeadline() async throws {
        let runner = ScriptedCommandRunner { call in
            try await Task.sleep(for: .milliseconds(300))
            return call.arguments.first == SimUseContract.Command.ui ? .screen(app: "A", platform: "android") : .daemonStop(stopped: true)
        }
        _ = try await Self.client(runner, device: Fixtures.emulator).observe()
        #expect(runner.recordedCalls.map(\.arguments.first) == ["ui"])
    }
}

/// Collects recovery reports.
final class Reports: Sendable {
    private let reports = Mutex<[DaemonRecovery]>([])

    var all: [DaemonRecovery] {
        reports.withLock { $0 }
    }

    func append(_ report: DaemonRecovery) {
        reports.withLock { $0.append(report) }
    }
}

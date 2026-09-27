import Foundation
@testable import JevSimUseKit
import Synchronization
import Testing

/// How a hung sim-use daemon can be mishandled, listed before the watchdog was written; the per-run replacement cap and
/// the wait-out after it are gone with the adaptive deadlines (`CallTimingTests`). A hung daemon made `ui` take
/// about 10 s, a fresh one hung again within a minute, and a stopped daemon process blocked a read for minutes; the E2E
/// hangs none on purpose, so every recovery path is here.
@Suite("A hung sim-use daemon is replaced without hiding a crash or a real failure")
struct DaemonWatchdogTests {
    private static let deadline: Duration = .milliseconds(100)
    private static let hang: Duration = .seconds(30)

    private static func client(
        _ runner: ScriptedCommandRunner, device: String = Fixtures.simulator, deadline: Duration = deadline,
        reports: Reports = Reports(),
    ) -> SimUseClient {
        let policy = CallTimingPolicy(floor: deadline, factor: 4, window: 5, ceiling: deadline, coldStart: deadline, coldSamples: 1)
        return SimUseClient(
            device: Fixtures.device(device),
            invoker: SimUseInvoker(executable: URL(filePath: "/sim-use"), runner: runner),
            timing: CallBaselines(policy: policy), report: { reports.append($0) },
        )
    }

    /// Daemon reads whose index is in `hanging` hang, the others show `app`; reads outside the daemon show `reread`, or
    /// `rereads` in turn, the last one repeated.
    private static func runner(
        hanging: Set<Int>, for delay: Duration = hang, app: String = "A", reread: String = "A",
        rereads: [CommandOutput] = [], stop: CommandOutput = .daemonStop(stopped: true),
    ) -> ScriptedCommandRunner {
        let daemonReads = Mutex(0)
        let outsideReads = Mutex(0)
        return ScriptedCommandRunner { call in
            if call.arguments.first == SimUseContract.Command.daemon {
                return stop
            }
            if call.bypassedDaemon {
                let index = outsideReads.withLock { reads in
                    defer { reads += 1 }
                    return reads
                }
                return rereads.isEmpty ? .screen(app: reread) : rereads[min(index, rereads.count - 1)]
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

    @Test("goes by the bundle id across the restart: right after a launch the label still named the previous app")
    func labelLags() async throws {
        let client = Self.client(Self.runner(hanging: [1], rereads: [.screen(app: "Previous", bundle: "A")]))
        _ = try await client.observe()
        #expect(try await client.observe().disappearedApps.isEmpty)
    }

    @Test("reads once more before calling the app gone, and keeps that reading, when the first one caught a transition")
    func rereadsBeforeCrash() async throws {
        let client = Self.client(Self.runner(hanging: [1], rereads: [.screen(app: "Home"), .screen(app: "A")]))
        _ = try await client.observe()
        let recovered = try await client.observe()
        #expect(recovered.disappearedApps.isEmpty)
        #expect(recovered.snapshot.appLabel == "A")
    }

    @Test("takes SpringBoard showing an alert over the app for the app still there, and its home screen for it gone")
    func springBoard() async throws {
        let alert = CommandOutput.screen(app: "SpringBoard", bundle: SimUseContract.springBoardBundle, entries: Self.alertEntries)
        let overApp = Self.client(Self.runner(hanging: [1], rereads: [alert]))
        _ = try await overApp.observe()
        #expect(try await overApp.observe().disappearedApps.isEmpty)

        let home = CommandOutput.screen(app: "SpringBoard", bundle: SimUseContract.springBoardBundle)
        let toHome = Self.client(Self.runner(hanging: [1], rereads: [home]))
        _ = try await toHome.observe()
        #expect(try await toHome.observe().disappearedApps.first?.hasPrefix("A") == true)
    }

    private static let alertEntries = #"[{"aliases":{"at":1},"depth":2,"frame":{"height":48,"width":288,"x":57,"y":458},"#
        + #""label":"B","role":"Button","states":[]}]"#

    @Test("leaves one slow but healthy read after a sheet opened alone under the live policy: no stop, no crash", .timeLimit(.minutes(1)))
    func slowHealthyRead() async throws {
        // Opening a sheet made one `ui` read take 3.05 s against reads of 0.54-0.59 s either side, every
        // time, at a load average of 9-13; the 3 s deadline took it for a hang and the app check then for a crash. A
        // device whose reads take 0.3 s puts the adaptive deadline on its floor, so the floor alone must clear it.
        let reads = Mutex(0)
        let runner = ScriptedCommandRunner { call in
            guard call.arguments.first == SimUseContract.Command.ui else { return .daemonStop(stopped: true) }
            let index = reads.withLock { reads in
                defer { reads += 1 }
                return reads
            }
            try await Task.sleep(for: index == 2 ? .milliseconds(3050) : .milliseconds(10))
            return .screen(app: "A")
        }
        let reports = Reports()
        let timing = CallBaselines()
        for _ in 0 ..< 5 {
            timing.record(.read, .milliseconds(300))
        }
        let client = SimUseClient(
            device: Fixtures.device(Fixtures.simulator),
            invoker: SimUseInvoker(executable: URL(filePath: "/sim-use"), runner: runner),
            timing: timing, report: { reports.append($0) },
        )
        for _ in 0 ..< 4 {
            #expect(try await client.observe().disappearedApps.isEmpty)
        }
        #expect(runner.recordedCalls.allSatisfy { $0.arguments.first == "ui" && !$0.bypassedDaemon })
        #expect(reports.all.isEmpty)
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
        // A deadline far past the cancellation, so a slow test machine cannot let it pass first.
        let client = Self.client(runner, deadline: .seconds(10))
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

import Foundation
@testable import JevSimUseKit
import Synchronization
import Testing

/// How one timing policy for sim-use calls can go wrong, listed before it was written. Durations are milliseconds and
/// hangs far longer, so scheduling noise cannot decide a result.
@Suite("sim-use call deadlines follow the device's own pace without letting one hang set it")
struct CallTimingTests {
    private static let policy = CallTimingPolicy(
        floor: .milliseconds(100), factor: 4, window: 5, ceiling: .milliseconds(200), coldStart: .milliseconds(400), coldSamples: 3,
    )

    @Test("waits generously before a baseline exists, since a run's first read also starts the daemon")
    func coldStart() {
        let baselines = CallBaselines(policy: Self.policy)
        #expect(baselines.deadline(for: .read) == .milliseconds(400))
        baselines.record(.read, .milliseconds(10))
        baselines.record(.read, .milliseconds(10))
        #expect(baselines.deadline(for: .read) == .milliseconds(400))
        baselines.record(.read, .milliseconds(10))
        #expect(baselines.deadline(for: .read) == .milliseconds(100))
    }

    @Test("stretches the deadline to a slow device's pace, by the median of recent calls")
    func stretches() {
        let baselines = CallBaselines(policy: Self.policy)
        for ms in [40, 50, 60, 1000, 45] {
            baselines.record(.read, .milliseconds(ms))
        }
        // The median, 50 ms, times 4 is the deadline; the one 1 s outlier does not move it.
        #expect(baselines.deadline(for: .read) == .milliseconds(200))
        #expect(baselines.baseline(.read) == .milliseconds(50))
    }

    @Test("caps the baseline, so a run of slow calls that still answered cannot stretch deadlines without end")
    func ceiling() {
        let baselines = CallBaselines(policy: Self.policy)
        for _ in 0 ..< 5 {
            baselines.record(.read, .seconds(30))
        }
        #expect(baselines.deadline(for: .read) == .milliseconds(800))
    }

    @Test("times a run's first actions by its reads, since the reads already started the daemon")
    func coldActionUsesReads() {
        let baselines = CallBaselines(policy: Self.policy)
        #expect(baselines.deadline(for: .action, intrinsic: .milliseconds(1500)) == .milliseconds(1900))
        for _ in 0 ..< 3 {
            baselines.record(.read, .milliseconds(40))
        }
        #expect(baselines.deadline(for: .action, intrinsic: .milliseconds(1500)) == .milliseconds(1660))
    }

    @Test("keeps reads and action overhead apart, and adds an action's own duration on top")
    func actionsApart() {
        let baselines = CallBaselines(policy: Self.policy)
        for _ in 0 ..< 3 {
            baselines.record(.read, .milliseconds(10))
            baselines.record(.action, .milliseconds(40))
        }
        #expect(baselines.deadline(for: .read) == .milliseconds(100))
        #expect(baselines.deadline(for: .action, intrinsic: .milliseconds(1500)) == .milliseconds(1660))
    }

    @Test("keeps the live floor clearly above the slowest healthy read seen, however fast the device's baseline")
    func liveFloor() {
        let baselines = CallBaselines()
        for _ in 0 ..< 5 {
            baselines.record(.read, .milliseconds(100))
        }
        // 4.73 s was the slowest healthy read measured, 3.05 s the one a sheet opening always takes; hangs took 10 s.
        #expect(baselines.deadline(for: .read) >= .milliseconds(4730) + .seconds(1))
        #expect(baselines.deadline(for: .read) < .seconds(10))
    }

    @Test("reads an action's own duration from its arguments, with sim-use's defaults where none is given", arguments: [
        (["gesture", "scroll-up", "--duration=1.5"], Duration.milliseconds(1500)),
        (["swipe", "--from=1,2", "--to=3,4", "--duration=1.2"], .milliseconds(1200)),
        (["long-press", "@4"], .milliseconds(800)),
        (["tap", "@4"], .zero),
        (["paste", "--replace"], .zero),
    ] as [([String], Duration)])
    func intrinsic(arguments: [String], expected: Duration) {
        #expect(CallTimingPolicy.intrinsicDuration(of: arguments) == expected)
    }
}

/// The inner layer on a real client: one deadline per sim-use call, one daemon stop per hang.
@Suite("A hung sim-use call is killed, the daemon stopped once, and a read retried outside it")
struct CallDeadlineTests {
    private static let policy = CallTimingPolicy(
        floor: .milliseconds(150), factor: 4, window: 5, ceiling: .milliseconds(200), coldStart: .milliseconds(150), coldSamples: 1,
    )
    private static let hang: Duration = .seconds(30)

    private static func client(_ runner: ScriptedCommandRunner, reports: Reports = Reports()) -> SimUseClient {
        SimUseClient(
            device: Fixtures.device(Fixtures.simulator),
            invoker: SimUseInvoker(executable: URL(filePath: "/sim-use"), runner: runner),
            timing: CallBaselines(policy: policy), report: { reports.append($0) },
        )
    }

    /// Answers `daemon stop`, screens, and actions; calls whose kind is in `hanging` sleep until cancelled.
    private static func runner(hangingReads: Bool = false, hangingRetry: Bool = false, hangingGesture: Bool = false,
                               gestureTakes: Duration = .zero) -> ScriptedCommandRunner
    {
        ScriptedCommandRunner { call in
            switch call.arguments.first {
            case SimUseContract.Command.daemon: return .daemonStop(stopped: true)
            case SimUseContract.Command.ui:
                if call.bypassedDaemon ? hangingRetry : hangingReads {
                    try await Task.sleep(for: hang)
                }
                return .screen(app: "A")
            case SimUseContract.Command.gesture:
                try await Task.sleep(for: hangingGesture ? hang : gestureTakes)
                return .json(#"{"ok":true,"data":{}}"#)
            default: return .json(#"{"ok":true,"data":{}}"#)
            }
        }
    }

    @Test("a real hang is caught at the floor on a fast device, and the read is taken outside the daemon")
    func hangCaughtUnderLightLoad() async throws {
        let reports = Reports()
        let runner = Self.runner(hangingReads: true)
        let clock = ContinuousClock()
        let start = clock.now
        let reading = try await Self.client(runner, reports: reports).observe()
        #expect(clock.now - start < .seconds(2))
        #expect(reading.snapshot.appLabel == "A")
        #expect(runner.recordedCalls.count { $0.arguments.first == SimUseContract.Command.daemon } == 1)
        #expect(reports.all.count == 1)
    }

    @Test("stops the daemon once when the retry outside it hangs too, and fails as a timeout the loop can count")
    func retryHangsToo() async throws {
        let runner = Self.runner(hangingReads: true, hangingRetry: true)
        await #expect(throws: SimUseError.self) { try await Self.client(runner).observe() }
        #expect(runner.recordedCalls.count { $0.arguments.first == SimUseContract.Command.daemon } == 1)
        let error = await #expect(throws: SimUseError.self) { try await Self.client(Self.runner(hangingReads: true, hangingRetry: true)).observe() }
        #expect(error?.isCallTimeout == true)
    }

    @Test("never records a hang in the baseline, so the next deadline is not poisoned by it")
    func hangNotRecorded() async throws {
        let timing = CallBaselines(policy: Self.policy)
        let client = SimUseClient(
            device: Fixtures.device(Fixtures.simulator),
            invoker: SimUseInvoker(executable: URL(filePath: "/sim-use"), runner: Self.runner(hangingReads: true)),
            timing: timing, report: { _ in },
        )
        _ = try await client.observe()
        #expect((timing.baseline(.read) ?? .zero) < .milliseconds(150))
    }

    @Test("lets a scroll run its own 1.5 s under a fast-tap baseline")
    func longGestureNotCut() async throws {
        let runner = Self.runner(gestureTakes: .milliseconds(400))
        _ = try await Self.client(runner).perform(.revealContentBelow, in: Fixtures.snapshot().space)
        #expect(runner.recordedCalls.count { $0.arguments.first == SimUseContract.Command.daemon } == 0)
    }

    @Test("kills a hung action, stops the daemon once, and does not send it again")
    func hungActionNotResent() async throws {
        let runner = Self.runner(hangingGesture: true)
        let error = await #expect(throws: SimUseError.self) {
            try await Self.client(runner).perform(.revealContentBelow, in: Fixtures.snapshot().space)
        }
        #expect(error?.isCallTimeout == true)
        #expect(runner.recordedCalls.count { $0.arguments.first == SimUseContract.Command.gesture } == 1)
        #expect(runner.recordedCalls.count { $0.arguments.first == SimUseContract.Command.daemon } == 1)
    }
}

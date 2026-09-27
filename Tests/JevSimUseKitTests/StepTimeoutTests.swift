@testable import JevSimUseKit
import Synchronization
import Testing

/// How the step timeout can go wrong where the E2E cannot reach: it needs a hang on cue. Timeouts are a few tenths of
/// a second and hangs are far longer, so scheduling noise cannot decide a result.
@Suite("A step that does not finish in time is cut off, retried once on a fresh reading, and ends the run the second time")
struct StepTimeoutTests {
    private static let timeout: Duration = .milliseconds(300)

    private static func run(
        _ driver: HangingDriver, _ plans: [StepPlan], timeout: Duration? = Self.timeout, planDelay: Duration = .zero,
    ) async throws -> AgentRunResult {
        let configuration = AgentConfiguration(goal: "g", maxSteps: 6, stepTimeout: timeout)
        return try await AgentLoop(driver: driver, planner: SlowPlanner(plans, delay: planDelay), configuration: configuration).run()
    }

    @Test("reads the screen and plans again after a cut action instead of sending it again, and says so in history")
    func cutActionIsNotResent() async throws {
        let driver = HangingDriver(outlines: ["A", "B"], hangingTaps: [1])
        let result = try await Self.run(driver, [.tapNext(), .done()])
        #expect(driver.taps == 1)
        // Only the per-call layer stops the daemon; the cycle's cut does not stop it a second time.
        #expect(driver.daemonStops == 0)
        #expect(result.outcome == .goalReached(steps: 1))
        let cut = try #require(result.history.first)
        #expect(cut.action.contains("cut off") && cut.action.contains("may or may not"))
        #expect(cut.screenChanged == false)
    }

    @Test("ends the run when the next cycle is cut off too, naming the step and what it waited for")
    func secondCutEndsRun() async throws {
        let driver = HangingDriver(outlines: ["A"], hangingTaps: [1, 2])
        let result = try await Self.run(driver, [.tapNext()])
        guard case let .stepTimedOut(step, waitingOn, _) = result.outcome else {
            Issue.record("expected a step timeout, got \(result.outcome)")
            return
        }
        #expect(step == 2 && waitingOn == .act)
        #expect(driver.daemonStops == 0)
    }

    @Test("forgets an earlier cut once a cycle finishes, so two cuts apart do not end the run")
    func cutsApartDoNotEndRun() async throws {
        let driver = HangingDriver(outlines: ["A", "B", "C"], hangingTaps: [1, 3])
        let result = try await Self.run(driver, [.tapNext(), .tapNext(), .tapNext(), .done()])
        #expect(result.outcome == .goalReached(steps: 3))
        // The reading that showed the second tap's effect was taken in the cycle cut off next, and still counts.
        #expect(result.history.map(\.screenChanged) == [false, true, false])
    }

    @Test("with the timeout off, a slow action is waited out")
    func offWaitsOut() async throws {
        let driver = HangingDriver(outlines: ["A", "B"], hangingTaps: [1], hang: .milliseconds(600))
        let result = try await Self.run(driver, [.tapNext(), .done()], timeout: nil)
        #expect(result.outcome == .goalReached(steps: 1))
        #expect(driver.daemonStops == 0)
    }

    @Test("treats a sim-use call that timed out during an action like a cut: re-read, not re-sent, and counted")
    func callTimeoutIsAnIncident() async throws {
        let driver = HangingDriver(outlines: ["A", "B"], timingOutTaps: [1])
        let result = try await Self.run(driver, [.tapNext(), .done()])
        #expect(driver.taps == 1)
        #expect(result.outcome == .goalReached(steps: 1))
        #expect(result.history.first?.action.contains("may or may not") == true)
        let twice = try await Self.run(HangingDriver(outlines: ["A"], timingOutTaps: [1, 2]), [.tapNext()])
        guard case .stepTimedOut = twice.outcome else {
            Issue.record("expected a step timeout, got \(twice.outcome)")
            return
        }
    }

    @Test("keeps its minimum reads after an unchanged action on a slow device, without the cycle's deadline cutting them")
    func waitsKeepTheirReads() async throws {
        let driver = HangingDriver(outlines: ["A"], readDelay: .milliseconds(100))
        // The first cycle's own reads (settling, confirming) must fit the deadline even on a slow CI runner, which a
        // 300 ms deadline over 120 ms reads did not; eight reads after the tap still outlast it.
        let configuration = AgentConfiguration(
            goal: "g", maxSteps: 1, unchangedWait: .milliseconds(10), stepTimeout: .milliseconds(600), minUnchangedReads: 8,
        )
        let result = try await AgentLoop(driver: driver, planner: SlowPlanner([.tapNext(), .blocked()], delay: .zero), configuration: configuration)
            .run()
        // Eight reads of 100 ms after the tap outlast the 600 ms cycle deadline; the wait is not part of it.
        #expect(driver.readsAfterFirstTap >= 8)
        if case .stepTimedOut = result.outcome {
            Issue.record("the wait's reads were cut off")
        }
    }

    @Test("cancels the confirming read when the cut lands while Jev plans")
    func cutCancelsConfirmingRead() async throws {
        let driver = HangingDriver(outlines: ["A"], hangingReadsAfter: 2)
        _ = try? await Self.run(driver, [.blocked()], planDelay: .seconds(5))
        try await Task.sleep(for: .milliseconds(100))
        #expect(driver.readsInFlight == 0)
    }
}

/// Hangs chosen taps (1-based) and, optionally, every read after the first `hangingReadsAfter`; counts daemon stops.
private final class HangingDriver: DeviceDriving {
    private let base: FakeDriver
    private let hangingTaps: Set<Int>
    private let hangingReadsAfter: Int?
    private let hang: Duration
    private let counts = Mutex((taps: 0, reads: 0, inFlight: 0, stops: 0, readsAfterTap: 0))

    private let timingOutTaps: Set<Int>
    private let readDelay: Duration

    init(
        outlines: [String], hangingTaps: Set<Int> = [], timingOutTaps: Set<Int> = [], hangingReadsAfter: Int? = nil,
        hang: Duration = .seconds(30), readDelay: Duration = .zero,
    ) {
        base = FakeDriver(outlines: outlines)
        self.hangingTaps = hangingTaps
        self.timingOutTaps = timingOutTaps
        self.hangingReadsAfter = hangingReadsAfter
        self.hang = hang
        self.readDelay = readDelay
    }

    /// Reads started after the first tap was sent.
    var readsAfterFirstTap: Int {
        counts.withLock { $0.readsAfterTap }
    }

    var taps: Int {
        counts.withLock { $0.taps }
    }

    var daemonStops: Int {
        counts.withLock { $0.stops }
    }

    var readsInFlight: Int {
        counts.withLock { $0.inFlight }
    }

    func observe() async throws -> ScreenObservation {
        let read = counts.withLock { counts in
            counts.reads += 1
            counts.inFlight += 1
            counts.readsAfterTap += counts.taps > 0 ? 1 : 0
            return counts.reads
        }
        defer { counts.withLock { $0.inFlight -= 1 } }
        try await Task.sleep(for: readDelay)
        if let hangingReadsAfter, read > hangingReadsAfter {
            try await Task.sleep(for: hang)
        }
        return try await base.observe()
    }

    func tap(alias: Int, on snapshot: UISnapshot) async throws -> [String] {
        let tap = counts.withLock { counts in
            counts.taps += 1
            return counts.taps
        }
        if hangingTaps.contains(tap) {
            try await Task.sleep(for: hang)
        }
        if timingOutTaps.contains(tap) {
            throw SimUseError.callTimedOut(command: "tap", seconds: 3, daemonStopped: true)
        }
        return try await base.tap(alias: alias, on: snapshot)
    }

    func perform(_ gesture: ElementGesture, alias: Int, on snapshot: UISnapshot) async throws -> [String] {
        try await base.perform(gesture, alias: alias, on: snapshot)
    }

    func perform(_ action: SimUseDeviceAction, in space: ScreenSpace) async throws -> [String] {
        try await base.perform(action, in: space)
    }

    func paste(_ text: String, replacing: Bool) async throws -> [String] {
        try await base.paste(text, replacing: replacing)
    }

    func stopDaemon() async -> Bool {
        counts.withLock { $0.stops += 1 }
        return true
    }
}

/// Returns plans in order (repeating the last), each after `delay`.
private final class SlowPlanner: StepPlanning {
    private let plans: [StepPlan]
    private let delay: Duration
    private let index = Mutex(0)

    init(_ plans: [StepPlan], delay: Duration) {
        self.plans = plans
        self.delay = delay
    }

    func plan(_: PlanRequest) async throws -> StepPlan {
        try await Task.sleep(for: delay)
        return index.withLock { index in
            defer { index += 1 }
            return plans[min(index, plans.count - 1)]
        }
    }
}

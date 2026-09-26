@testable import JevSimUseKit
import Testing

/// How a step's timing can mislead, listed before it was measured. The E2E shows the numbers but cannot tell a
/// double-counted read from a slow one, so the attribution is checked here with delays that dwarf scheduling noise.
/// Bounds are fractions of those delays, never absolute times: a CI runner measured 0.14 s of loop overhead where a
/// fixed 0.1 s bound expected none.
@Suite("Step timings add up to the time the loop waited and blame each wait on what it waited for")
struct StepTimingTests {
    private static let slow: Duration = .milliseconds(500)
    /// `slow` in seconds, for bounds on the measured parts.
    private static let slowSeconds = slow / .seconds(1)

    private static func run(readDelay: Duration, planDelay: Duration) async throws -> (AgentRunResult, Duration) {
        let driver = DelayedDriver(FakeDriver(outlines: ["A", "B"]), readDelay: readDelay)
        let planner = DelayedPlanner(FakePlanner([.tapNext(), .done()]), delay: planDelay)
        let clock = ContinuousClock()
        let start = clock.now
        let result = try await AgentLoop(driver: driver, planner: planner, configuration: AgentConfiguration(goal: "g")).run()
        return (result, clock.now - start)
    }

    @Test("does not count the confirming read that runs while Jev answers, so the parts never exceed the run's time")
    func overlappedReadCountedOnce() async throws {
        let (result, wall) = try await Self.run(readDelay: .milliseconds(150), planDelay: Self.slow)
        #expect(result.timing.total <= wall / .seconds(1))
    }

    @Test("blames a slow Jev reply on Jev, not on the screen reads it overlapped")
    func slowJevIsJev() async throws {
        let (result, _) = try await Self.run(readDelay: .zero, planDelay: Self.slow)
        // Two plans each wait `slow`. Blamed on reading, the confirming read would count about as much as Jev.
        #expect(result.timing.jev >= 2 * Self.slowSeconds)
        #expect(result.timing.read < Self.slowSeconds / 2)
    }

    @Test("counts the wait for a confirming read that outlasts Jev's reply as reading")
    func slowConfirmationIsRead() async throws {
        let (result, _) = try await Self.run(readDelay: Self.slow, planDelay: .zero)
        let first = try #require(result.history.first?.timing)
        // The step's first reading, then the confirming reading that Jev's instant reply left the loop waiting for.
        #expect(first.read >= 1.5 * Self.slowSeconds)
        // Blamed on Jev, the wait for the confirming read would make this about `slow`.
        #expect(first.jev < Self.slowSeconds / 2)
    }

    @Test("keeps each action's timing in history and adds the last step, which took no action, to the run's total")
    func recordsTimings() async throws {
        let (result, _) = try await Self.run(readDelay: .milliseconds(100), planDelay: .milliseconds(100))
        let first = try #require(result.history.first?.timing)
        #expect(result.history.count == 1)
        #expect(result.timing.jev >= first.jev + 0.08)
        #expect(result.timing.read >= first.read + 0.08)
    }
}

/// Delays every screen read by `readDelay`.
private final class DelayedDriver: DeviceDriving {
    private let base: FakeDriver
    private let readDelay: Duration

    init(_ base: FakeDriver, readDelay: Duration) {
        self.base = base
        self.readDelay = readDelay
    }

    func observe() async throws -> ScreenObservation {
        try await Task.sleep(for: readDelay)
        return try await base.observe()
    }

    func tap(alias: Int, on snapshot: UISnapshot) async throws -> [String] {
        try await base.tap(alias: alias, on: snapshot)
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
}

/// Delays every plan by `delay`.
private struct DelayedPlanner: StepPlanning {
    let base: FakePlanner
    let delay: Duration

    init(_ base: FakePlanner, delay: Duration) {
        self.base = base
        self.delay = delay
    }

    func plan(_ request: PlanRequest) async throws -> StepPlan {
        try await Task.sleep(for: delay)
        return try await base.plan(request)
    }
}

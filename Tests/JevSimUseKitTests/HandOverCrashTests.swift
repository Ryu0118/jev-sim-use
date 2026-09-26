@testable import JevSimUseKit
import Synchronization
import Testing

/// Before handing over, the loop keeps reading for a screen that moves on and throws away the readings that did not. An
/// app that disappeared is reported only once, on whichever reading comes next, so a thrown-away reading took the crash
/// with it and the run handed over as if nothing had happened. The E2E never crashes an app, so these guard it here.
@Suite("The hand-over wait keeps every disappeared app it reads")
struct HandOverCrashTests {
    private static func loop(_ driver: CountingDriver, handOverWait: Duration = .zero) -> AgentLoop {
        AgentLoop(
            driver: driver, planner: FakePlanner([.blocked()]),
            configuration: AgentConfiguration(goal: "g", handOverWait: handOverWait),
        )
    }

    @Test("stops the hand-over for an app that disappeared in a reading the wait throws away")
    func handOverKeepsDiscardedCrash() async throws {
        let driver = CountingDriver(["A", "A", "A!"])
        let outcome = try await Self.loop(driver).run().outcome
        #expect(outcome == .appCrashed(detail: "the app disappeared (com.example.app)."))
    }

    @Test("carries a disappearance from a thrown-away reading into the reading the hand-over wait keeps")
    func handOverMergesIntoChangedReading() async throws {
        let driver = CountingDriver(["A", "A", "A!", "B"])
        let outcome = try await Self.loop(driver, handOverWait: .seconds(2)).run().outcome
        #expect(outcome == .appCrashed(detail: "the app disappeared (com.example.app)."))
    }

    @Test("still reads once without a wait and keeps reading for the whole wait, so the fix adds or drops no reading")
    func handOverWaitBudget() async throws {
        let once = CountingDriver(["A"])
        #expect(try await !Self.loop(once).reading(changedFrom: CountingDriver.screen("A")).changed)
        #expect(once.reads == 1)

        let waiting = CountingDriver(["A"], delay: .milliseconds(20))
        _ = try await Self.loop(waiting, handOverWait: .milliseconds(200)).reading(changedFrom: CountingDriver.screen("A"))
        #expect(waiting.reads > 3)
    }
}

/// Reads `outlines` in order, repeating the last; an outline ending in `!` also reports the app gone. Counts reads.
private final class CountingDriver: DeviceDriving {
    private let outlines: [String]
    private let delay: Duration
    private let count = Mutex(0)

    var reads: Int {
        count.withLock { $0 }
    }

    init(_ outlines: [String], delay: Duration = .zero) {
        self.outlines = outlines
        self.delay = delay
    }

    func observe() async throws -> ScreenObservation {
        try await Task.sleep(for: delay)
        let outline = count.withLock { count in
            defer { count += 1 }
            return outlines[min(count, outlines.count - 1)]
        }
        let crashed = outline.hasSuffix("!")
        return ScreenObservation(
            snapshot: Self.screen(crashed ? String(outline.dropLast()) : outline),
            disappearedApps: crashed ? ["com.example.app"] : [],
        )
    }

    /// A screen whose only element is a heading named `name`.
    static func screen(_ name: String) -> UISnapshot {
        Fixtures.snapshot(outline: name, entries: [Fixtures.entry(0, name, role: "Heading")])
    }

    func tap(alias _: Int, on _: UISnapshot) async throws -> [String] {
        []
    }

    func perform(_: ElementGesture, alias _: Int, on _: UISnapshot) async throws -> [String] {
        []
    }

    func perform(_: SimUseDeviceAction, in _: ScreenSpace) async throws -> [String] {
        []
    }

    func paste(_: String, replacing _: Bool) async throws -> [String] {
        []
    }
}

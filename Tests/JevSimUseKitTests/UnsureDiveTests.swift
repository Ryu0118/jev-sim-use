@testable import JevSimUseKit
import Testing

/// Jev opened a section the goal did not name (0.51-0.77) while the named item sat further down the list. With no code
/// scrolling on Jev's behalf, what keeps that from becoming a wrong dive is the support bar: an unsure tap hands over.
/// The goal's script must not change that.
@Suite("An unsure dive into an unnamed section hands over, whatever script the goal names its item in")
struct UnsureDiveTests {
    @Test("hands over the unsure tap without acting or scrolling", arguments: [
        "Open the Developer screen in Settings", "Open the デベロッパ screen in Settings",
    ])
    func handsOver(goal: String) async throws {
        let rows = ["General", "Accessibility", "Camera", "Search", "Siri"].enumerated().map { index, label in
            Fixtures.entry(index + 1, label, frame: ElementFrame(x: 16, y: 120 + Double(index * 52), width: 370, height: 52))
        }
        let snapshot = UISnapshot(platform: "ios", outline: "list", appLabel: "Settings", entries: rows, crashDialog: nil)
        let dive = StepPlan(action: .tap(alias: 1, role: "Button", label: "General"), confidence: 0.5, costUSD: 0)
        let driver = ScriptedDriver(readings: [snapshot])
        let outcome = try await AgentLoop(driver: driver, planner: FakePlanner([dive]), configuration: AgentConfiguration(goal: goal))
            .run().outcome
        #expect(outcome == .escalated(step: 1, action: dive.action, confidence: 0.5))
        #expect(driver.performedActions.isEmpty)
    }
}

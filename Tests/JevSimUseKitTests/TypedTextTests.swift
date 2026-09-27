import Foundation
@testable import JevSimUseKit
import Synchronization
import Testing

/// Whether pasted text reached its field, judged from the reading after the paste. A simulator whose pasteboard and
/// key events never reached the app reported the paste as done, and an event was saved as "New Event".
struct TypedTextTests {
    private static func field(_ label: String, value: String?, role: String = "TextField", width: Double = 336) -> UIEntry {
        Fixtures.entry(7, label, role: role, value: value, frame: ElementFrame(x: 33, y: 803, width: width, height: 38))
    }

    private static func landed(_ text: String, before: UIEntry, after: [UIEntry]) -> Bool? {
        Fixtures.snapshot(entries: [before]).typedText(text, landedIn: 7, after: Fixtures.snapshot(entries: after))
    }

    @Test("lands when the field then holds the text, although focus narrowed the field")
    func holdsText() {
        #expect(Self.landed("Keyboard", before: Self.field("Search", value: "Search"),
                            after: [Self.field("Search", value: "Keyboard", width: 276)]) == true)
    }

    @Test("does not land when the field still shows its placeholder")
    func placeholderStays() {
        #expect(Self.landed("Keyboard", before: Self.field("Search", value: "Search"),
                            after: [Self.field("Search", value: "Search", width: 276)]) == false)
    }

    @Test("does not land when a replaced field keeps its old text")
    func replacedKeepsOld() {
        #expect(Self.landed("Weekly", before: Self.field("Title", value: "Draft"), after: [Self.field("Title", value: "Draft")]) == false)
    }

    @Test("lands in a secure field, which shows bullets instead of the text", arguments: ["••••••", "\u{2022}\u{2022}\u{2022}"])
    func secureField(masked: String) {
        #expect(Self.landed("hunter22", before: Self.field("Password", value: nil, role: "SecureTextField"),
                            after: [Self.field("Password", value: masked, role: "SecureTextField")]) == true)
    }

    @Test("lands in a field that reformats what was typed", arguments: [
        ("5551234567", "(555) 123-4567"),
        ("2026-09-27", "Sep 27, 2026"),
    ])
    func reformatted(text: String, shown: String) {
        #expect(Self.landed(text, before: Self.field("Phone", value: nil), after: [Self.field("Phone", value: shown)]) == true)
    }

    @Test("cannot tell when the field is gone, as after a search that ran on paste")
    func fieldGone() {
        #expect(Self.landed("Keyboard", before: Self.field("Search", value: "Search"), after: []) == nil)
    }
}

/// What the loop does when pasted text did not reach its field. The value stays on this machine.
struct TypedTextLoopTests {
    private static let secret = "Quarterly review"

    /// A form whose title field holds `value`; `extra` adds a button, so the screen reads as changed.
    private static func screen(_ value: String?, _ outline: String, extra: Bool = false) -> UISnapshot {
        let field = Fixtures.entry(1, "Title", role: "TextField", value: value, frame: ElementFrame(x: 43, y: 156, width: 295, height: 28))
        return Fixtures.snapshot(outline: outline, entries: [field] + (extra ? [Fixtures.entry(2, "Clear text")] : []))
    }

    private static let typing = StepPlan(
        action: .enterText(field: 1, label: "Title", text: InputText(name: "title", value: secret)), confidence: 0.9, costUSD: 0,
    )

    private static func run(_ driver: ScriptedDriver, _ planner: some StepPlanning) async throws -> AgentOutcome {
        try await AgentLoop(driver: driver, planner: planner, configuration: AgentConfiguration(goal: "g", maxSteps: 4)).run().outcome
    }

    @Test("stops with a setup error when the text did not land and the simulator's pasteboard does not hold it")
    func pasteboardEmpty() async throws {
        let driver = ScriptedDriver(readings: [Self.screen("Title", "Form"), Self.screen("Title", "Form")], pasteboard: false)
        await #expect(throws: SimUseError.pasteboardUnavailable) {
            try await Self.run(driver, FakePlanner([Self.typing, .done()]))
        }
        #expect(FailureCategory(SimUseError.pasteboardUnavailable) == .setup)
    }

    @Test("tells Jev the text did not appear, without the text, and stops with a setup error on a second miss")
    func notLandedTwice() async throws {
        let driver = ScriptedDriver(
            readings: [Self.screen("Title", "Form"), Self.screen("Title", "Form", extra: true), Self.screen("Title", "Form")],
            pasteboard: nil,
        )
        let planner = StateRecordingPlanner([Self.typing, Self.typing])
        await #expect(throws: SimUseError.typedTextNotLanded) {
            try await Self.run(driver, planner)
        }
        let second = try #require(planner.states.dropFirst().first)
        #expect(second.contains("the typed text did not appear in the field"))
        #expect(!planner.states.contains { $0.contains(Self.secret) })
        #expect(FailureCategory(SimUseError.typedTextNotLanded) == .setup)
    }

    @Test("goes on when the field shows the text")
    func landed() async throws {
        let driver = ScriptedDriver(readings: [Self.screen("Title", "Form"), Self.screen(Self.secret, "Form filled")], pasteboard: false)
        #expect(try await Self.run(driver, FakePlanner([Self.typing, .done()])) == .goalReached(steps: 1))
    }

    @Test("does not judge Android, whose field values were never observed")
    func android() async throws {
        let form = UISnapshot(platform: "android", outline: "Form", appLabel: "App", entries: Self.screen("Title", "Form").entries, crashDialog: nil)
        let driver = ScriptedDriver(readings: [form], pasteboard: false)
        #expect(try await Self.run(driver, FakePlanner([Self.typing, .done()])) == .goalReached(steps: 1))
    }
}

/// Plays `plans` in order and keeps each planning state as JSON.
private final class StateRecordingPlanner: StepPlanning {
    private let plans: Mutex<[StepPlan]>
    private let recorded = Mutex<[String]>([])

    init(_ plans: [StepPlan]) {
        self.plans = Mutex(plans)
    }

    var states: [String] {
        recorded.withLock { $0 }
    }

    func plan(_ request: PlanRequest) async throws -> StepPlan {
        let json = try String(decoding: JSONEncoder().encode(PlanningState(request)), as: UTF8.self)
        recorded.withLock { $0.append(json) }
        return plans.withLock { $0.isEmpty ? .blocked() : $0.removeFirst() }
    }
}

@testable import JevSimUseKit
import Testing

/// A row tapped 26 times never opened while a relative time on the screen ticked, so every screen looked new. The loop
/// handing over at the fourth tap runs end to end in scripts/e2e.sh; these are the screen sequences the guard must tell
/// apart.
@Suite("The same action repeated on a screen whose elements stay put is refused, even while a value there ticks")
struct RepeatGuardTests {
    private static let open = AgentAction.tap(alias: 1, role: "Button", label: "Open")

    /// A screen with the row to open, its relative time, and `extra` elements.
    private static func screen(_ minutes: Int, _ extra: [String] = []) -> UISnapshot {
        let row = Fixtures.entry(1, "Open", value: "\(minutes) minutes ago")
        let others = extra.enumerated().map { Fixtures.entry($0.offset + 2, $0.element, role: "StaticText") }
        return Fixtures.snapshot(outline: "screen \(minutes) \(extra)", entries: [row] + others)
    }

    @Test("refuses the fourth identical action only when it keeps landing on the same elements", arguments: [
        ("the same elements, a value ticking", (0 ... 3).map { screen($0) }, true),
        ("alternating between two sets of elements", (0 ... 3).map { screen($0, $0.isMultiple(of: 2) ? [] : ["Sort by date"]) }, true),
        ("a new page each time, like a Next button", (0 ... 3).map { screen($0, ["Page \($0)"]) }, false),
    ] as [(String, [UISnapshot], Bool)])
    func repeats(_: String, screens: [UISnapshot], futile: Bool) {
        var progress = AgentProgress()
        _ = progress.record(ScreenObservation(snapshot: screens[0], disappearedApps: []), stallLimit: 9)
        for screen in screens.dropFirst() {
            #expect(!progress.isFutileRepeat(Self.open), "refused before the limit")
            progress.recordAction(Self.open, disappeared: [])
            _ = progress.record(ScreenObservation(snapshot: screen, disappearedApps: []), stallLimit: 9)
        }
        #expect(progress.isFutileRepeat(Self.open) == futile)
        #expect(!progress.isFutileRepeat(.tap(alias: 2, role: "Button", label: "Other")), "another action is never refused")
        #expect(!progress.isFutileRepeat(.wait), "waiting out a slow save is never refused")
    }
}

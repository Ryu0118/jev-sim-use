@testable import JevSimUseKit
import Testing

/// A repeated action counts toward the repeat limit only when it left the screen's state as one already seen in the
/// run. A value that changes on its own (seen changing between two readings with no action between, like a relative
/// time) does not count as an effect. Written before the code; each row is one way the guard can misjudge a repeat.
@Suite("A repeat counts only when it did not move the screen to a new state")
struct RepeatEffectTests {
    /// One tap repeated `values.count - 1` times: `values[n]` is the counter's value after `n` taps, and `ticks[n]`
    /// the relative time on a row that changes on its own.
    struct Sequence: Sendable, CustomTestStringConvertible {
        let testDescription: String
        let values: [String]
        var ticks: [String]?
        /// Whether a second reading, taken with no action after each one, shows the row's time already moved on.
        var tickSeenBetweenReadings = false
        /// Whether the counter moves down the screen after each tap.
        var moves = false
        /// Whether the tapped element's alias changes after each tap.
        var aliasChanges = false
        let refusedAfter: Int?
    }

    static let increment = "Increment"

    static func screen(_ index: Int, _ sequence: Sequence) -> UISnapshot {
        let y = sequence.moves ? 200 + Double(index * 10) : 200
        var entries = [
            Fixtures.entry(sequence.aliasChanges ? 10 + index : 1, increment, frame: ElementFrame(x: 300, y: y, width: 80, height: 32)),
            Fixtures.entry(2, "Count", role: "StaticText", value: sequence.values[index]),
        ]
        if let ticks = sequence.ticks {
            entries.append(Fixtures.entry(3, "Saved", role: "StaticText", value: ticks[index]))
        }
        return Fixtures.snapshot(outline: "screen \(index)", entries: entries)
    }

    @Test("refuses a repeat only after the limit of taps that led nowhere new", arguments: [
        Sequence(testDescription: "a counter that goes up with every tap is never refused",
                 values: ["1", "2", "3", "4", "5", "6"], refusedAfter: nil),
        Sequence(testDescription: "a tap that changes nothing is refused after three",
                 values: ["1", "1", "1", "1"], refusedAfter: 3),
        Sequence(testDescription: "a tap that changes nothing while a time ticks on its own is refused after three",
                 values: ["1", "1", "1", "1"], ticks: ["1 s", "3 s", "5 s", "7 s"], tickSeenBetweenReadings: true,
                 refusedAfter: 3),
        Sequence(testDescription: "a switch flipped back and forth is refused once its states repeat",
                 values: ["0", "1", "0", "1", "0", "1"], refusedAfter: 4),
        Sequence(testDescription: "an element that moves but keeps its value is refused after three",
                 values: ["1", "1", "1", "1"], moves: true, refusedAfter: 3),
        Sequence(testDescription: "a counter whose alias changes after each tap is still the same repeated tap",
                 values: ["1", "2", "3", "4", "5"], aliasChanges: true, refusedAfter: nil),
    ])
    func repeats(_ sequence: Sequence) {
        var progress = AgentProgress()
        _ = progress.record(ScreenObservation(snapshot: Self.screen(0, sequence), disappearedApps: []), stallLimit: 99)
        var refusedAt: Int?
        for index in 1 ..< sequence.values.count {
            let alias = sequence.aliasChanges ? 10 + index - 1 : 1
            let tap = AgentAction.tap(alias: alias, role: "Button", label: Self.increment)
            if progress.isFutileRepeat(tap) {
                refusedAt = index - 1
                break
            }
            progress.recordAction(tap, disappeared: [])
            let after = Self.screen(index, sequence)
            _ = progress.record(ScreenObservation(snapshot: after, disappearedApps: []), stallLimit: 99)
            if sequence.tickSeenBetweenReadings, var ticks = sequence.ticks {
                ticks[index] += " later"
                progress.noteReading(Self.screen(index, Sequence(
                    testDescription: "", values: sequence.values, ticks: ticks, refusedAfter: nil,
                )))
            }
        }
        if refusedAt == nil {
            let tap = AgentAction.tap(alias: 1, role: "Button", label: Self.increment)
            refusedAt = progress.isFutileRepeat(tap) ? sequence.values.count - 1 : nil
        }
        #expect(refusedAt == sequence.refusedAfter)
    }

    @Test("a value that changes between two readings after a tap whose effect had not shown yet is not taken as ticking")
    func lateEffectIsNotTicking() {
        let sequence = Sequence(testDescription: "", values: ["1", "1", "2", "3", "4", "5"], refusedAfter: nil)
        var progress = AgentProgress()
        _ = progress.record(ScreenObservation(snapshot: Self.screen(0, sequence), disappearedApps: []), stallLimit: 99)
        let tap = AgentAction.tap(alias: 1, role: "Button", label: Self.increment)
        progress.recordAction(tap, disappeared: [])
        // The first reading after the tap still shows the old value; the confirming one shows the new value.
        _ = progress.record(ScreenObservation(snapshot: Self.screen(1, sequence), disappearedApps: []), stallLimit: 99)
        progress.noteReading(Self.screen(2, sequence))
        for index in 2 ..< sequence.values.count {
            #expect(!progress.isFutileRepeat(tap))
            progress.recordAction(tap, disappeared: [])
            _ = progress.record(ScreenObservation(snapshot: Self.screen(index, sequence), disappearedApps: []), stallLimit: 99)
        }
        #expect(!progress.isFutileRepeat(tap))
    }

    @Test("waiting is never refused, however often the screen stays the same")
    func waitExempt() {
        let sequence = Sequence(testDescription: "", values: ["1", "1", "1", "1", "1"], refusedAfter: nil)
        var progress = AgentProgress()
        _ = progress.record(ScreenObservation(snapshot: Self.screen(0, sequence), disappearedApps: []), stallLimit: 99)
        for index in 1 ..< sequence.values.count {
            progress.recordAction(.wait, disappeared: [])
            _ = progress.record(ScreenObservation(snapshot: Self.screen(index, sequence), disappearedApps: []), stallLimit: 99)
        }
        #expect(!progress.isFutileRepeat(.wait))
    }
}

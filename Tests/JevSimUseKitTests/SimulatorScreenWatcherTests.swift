import Foundation
@testable import JevSimUseKit
import Testing

/// Ways the live watcher can mislead the loop or outlive its run: counting the status bar's clock as a change, a
/// frame that changed nothing, a screen that never stops moving, and callbacks left registered with CoreSimulator.
@Suite("The simulator watcher reports content changes and stillness, and unregisters what it registered")
struct SimulatorScreenWatcherTests {
    private static let contentRows = 100 ..< 110
    private static let statusBarRows = 0 ..< 5

    private static func deadline(_ milliseconds: Int) -> ContinuousClock.Instant {
        .now + .milliseconds(milliseconds)
    }

    @Test("unregisters both callbacks it registered, under the same id, once")
    func unregistersOnClose() throws {
        let display = FakeDisplayDescriptor()
        let watcher = try SimulatorScreenWatcher(display: display)
        #expect(display.registered.count == 2)
        watcher.close()
        watcher.close()
        #expect(display.unregistered.sorted() == display.registered.sorted())
    }

    @Test("ignores a change inside the status bar's band, such as the clock ticking")
    func statusBarOnlyIgnored() async throws {
        let display = FakeDisplayDescriptor()
        let watcher = try SimulatorScreenWatcher(display: display)
        defer { watcher.close() }
        let start = ContinuousClock.now
        display.draw(rows: Self.statusBarRows, value: 0x7F)
        #expect(try await !watcher.waitForChange(after: start, until: Self.deadline(300)))
        display.draw(rows: Self.contentRows, value: 0x7F)
        #expect(try await watcher.waitForChange(after: start, until: Self.deadline(2000)))
    }

    /// The render server reports frames that change no pixel, and the first comparison has no earlier frame.
    @Test("does not count a frame that changed nothing, including the first one after attaching")
    func unchangedFrameIgnored() async throws {
        let display = FakeDisplayDescriptor()
        let watcher = try SimulatorScreenWatcher(display: display)
        defer { watcher.close() }
        let start = ContinuousClock.now
        display.draw(rows: 0 ..< 0, value: 0)
        #expect(try await !watcher.waitForChange(after: start, until: Self.deadline(300)))
    }

    @Test("does not count a change from before the given instant")
    func earlierChangeIgnored() async throws {
        let display = FakeDisplayDescriptor()
        let watcher = try SimulatorScreenWatcher(display: display)
        defer { watcher.close() }
        display.draw(rows: Self.contentRows, value: 0x7F)
        #expect(try await watcher.waitForChange(after: .now - .seconds(1), until: Self.deadline(2000)))
        #expect(try await !watcher.waitForChange(after: .now, until: Self.deadline(300)))
    }

    @Test("returns at the deadline while the screen keeps moving, and reports stillness once it stops")
    func animationHitsDeadline() async throws {
        let display = FakeDisplayDescriptor()
        let watcher = try SimulatorScreenWatcher(display: display)
        defer { watcher.close() }
        let animation = Task {
            var value: UInt8 = 0
            while !Task.isCancelled {
                value &+= 1
                display.draw(rows: Self.contentRows, value: value)
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        #expect(try await watcher.waitForChange(after: .now, until: Self.deadline(2000)))
        let started = ContinuousClock.now
        let still = try await watcher.waitUntilStill(for: .milliseconds(150), until: Self.deadline(500))
        animation.cancel()
        #expect(!still)
        #expect(ContinuousClock.now - started < .seconds(3))
        #expect(try await watcher.waitUntilStill(for: .milliseconds(150), until: Self.deadline(3000)))
    }

    @Test("counts a replaced surface as a change, and compares later frames with the new one")
    func surfaceReplacement() async throws {
        let display = FakeDisplayDescriptor()
        let watcher = try SimulatorScreenWatcher(display: display)
        defer { watcher.close() }
        let start = ContinuousClock.now
        display.replaceSurface(filledWith: 0x40)
        #expect(try await watcher.waitForChange(after: start, until: Self.deadline(2000)))
        let later = ContinuousClock.now
        display.draw(rows: 0 ..< 0, value: 0)
        #expect(try await !watcher.waitForChange(after: later, until: Self.deadline(300)))
    }

    @Test("ignores frames reported after it was closed")
    func framesAfterCloseIgnored() async throws {
        let display = FakeDisplayDescriptor()
        let watcher = try SimulatorScreenWatcher(display: display)
        watcher.close()
        let start = ContinuousClock.now
        display.draw(rows: Self.contentRows, value: 0x7F)
        #expect(try await !watcher.waitForChange(after: start, until: Self.deadline(200)))
    }

    @Test("refuses a display without the framebuffer selectors, so the loop falls back to polling")
    func missingSelectors() {
        #expect(throws: ScreenWatchError.selectorMissing("framebufferSurface")) {
            try SimulatorScreenWatcher(display: NSObject())
        }
    }
}

/// The comparison behind the watcher: which rows count, and what the first frame means.
@Suite("Frames are compared below the status bar's band")
struct FrameBaselineTests {
    private static let bytesPerRow = 16
    private static let height = 200

    private static func frame(_ value: UInt8 = 0, rows: Range<Int> = 0 ..< 0) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        for row in rows {
            bytes.replaceSubrange(row * bytesPerRow ..< (row + 1) * bytesPerRow, with: repeatElement(value, count: bytesPerRow))
        }
        return bytes
    }

    private static func absorb(_ frame: [UInt8], into baseline: inout FrameBaseline) -> Bool {
        frame.withUnsafeBytes { baseline.absorb($0, bytesPerRow: bytesPerRow, height: height) }
    }

    @Test("takes the first frame as the baseline, not as a change")
    func firstFramePrimes() {
        var baseline = FrameBaseline()
        #expect(!Self.absorb(Self.frame(0xFF, rows: 0 ..< Self.height), into: &baseline))
    }

    @Test("counts rows below the band and ignores rows inside it", arguments: [(0 ..< 6, false), (150 ..< 160, true)])
    func band(rows: Range<Int>, counts: Bool) {
        var baseline = FrameBaseline()
        _ = Self.absorb(Self.frame(), into: &baseline)
        #expect(Self.absorb(Self.frame(0x7F, rows: rows), into: &baseline) == counts)
        #expect(!Self.absorb(Self.frame(0x7F, rows: rows), into: &baseline))
    }

    /// A text field's caret blinks for as long as the field has focus: counted as a change, a screen with a focused
    /// field never goes still, and every wait after typing ran to its deadline.
    @Test("ignores a change only a few pixels wide, such as a blinking caret, and counts a wider one", arguments: [
        (100 ..< 112, false), (100 ..< 400, true),
    ])
    func narrowChange(columns: Range<Int>, counts: Bool) {
        let bytesPerRow = 4000
        var baseline = FrameBaseline()
        let blank = [UInt8](repeating: 0, count: bytesPerRow * Self.height)
        var drawn = blank
        for row in 150 ..< 180 {
            drawn.replaceSubrange(row * bytesPerRow + columns.lowerBound ..< row * bytesPerRow + columns.upperBound,
                                  with: repeatElement(0x7F, count: columns.count))
        }
        _ = blank.withUnsafeBytes { baseline.absorb($0, bytesPerRow: bytesPerRow, height: Self.height) }
        #expect(drawn.withUnsafeBytes { baseline.absorb($0, bytesPerRow: bytesPerRow, height: Self.height) } == counts)
    }

    @Test("starts over when the frame's size changes, as after the surface was replaced")
    func resized() {
        var baseline = FrameBaseline()
        _ = Self.absorb(Self.frame(), into: &baseline)
        let wider = [UInt8](repeating: 0, count: Self.bytesPerRow * 2 * Self.height)
        #expect(wider.withUnsafeBytes { baseline.absorb($0, bytesPerRow: Self.bytesPerRow * 2, height: Self.height) })
    }
}

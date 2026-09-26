@testable import JevSimUseKit
import Synchronization

/// Shows `outlines[n]` after `n` actions (repeating the last), however often the screen is read, and records actions.
final class FakeDriver: DeviceDriving {
    private let observations: [ScreenObservation]
    private let disappearedAfterAction: [String]
    private let state = Mutex<[String]>([])

    var performedActions: [String] {
        state.withLock { $0 }
    }

    init(
        outlines: [String],
        entries: [UIEntry] = [Fixtures.entry(1, "Next")],
        disappearedAfterEachAction: [String] = [],
    ) {
        observations = outlines.map { outline in
            // The outline names the screen, so it is also an element: screens are compared by their elements.
            let heading = Fixtures.entry(0, outline, role: "Heading")
            let snapshot = Fixtures.snapshot(outline: outline, entries: entries + [heading])
            return ScreenObservation(snapshot: snapshot, disappearedApps: [])
        }
        disappearedAfterAction = disappearedAfterEachAction
    }

    func observe() async throws -> ScreenObservation {
        state.withLock { observations[min($0.count, observations.count - 1)] }
    }

    func tap(alias: Int, on _: UISnapshot) async throws -> [String] {
        record("tap @\(alias)")
    }

    func perform(_ gesture: ElementGesture, alias: Int, on _: UISnapshot) async throws -> [String] {
        record("\(gesture.rawValue) @\(alias)")
    }

    func perform(_ action: SimUseDeviceAction, platform _: String) async throws -> [String] {
        record("\(action)")
    }

    func paste(_ text: String, replacing: Bool) async throws -> [String] {
        record(replacing ? "paste --replace \(text)" : "paste \(text)")
    }

    private func record(_ action: String) -> [String] {
        state.withLock { $0.append(action) }
        return disappearedAfterAction
    }
}

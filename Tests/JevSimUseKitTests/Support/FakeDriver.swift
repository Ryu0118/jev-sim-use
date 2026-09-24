@testable import JevSimUseKit
import Synchronization

/// Serves observations in order (repeating the last) and records actions.
final class FakeDriver: DeviceDriving {
    private let observations: [ScreenObservation]
    private let disappearedAfterAction: [String]
    private let state = Mutex<(index: Int, actions: [String])>((0, []))

    var performedActions: [String] {
        state.withLock { $0.actions }
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
        state.withLock { state in
            defer { state.index += 1 }
            return observations[min(state.index, observations.count - 1)]
        }
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

    func paste(_ text: String) async throws -> [String] {
        record("paste \(text)")
    }

    private func record(_ action: String) -> [String] {
        state.withLock { $0.actions.append(action) }
        return disappearedAfterAction
    }
}

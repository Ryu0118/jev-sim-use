@testable import JevSimUseKit
import Synchronization

/// Returns one reading per `observe` call, in order (repeating the last): a screen that is still changing. Records
/// every action.
final class ScriptedDriver: DeviceDriving {
    private let readings: [ScreenObservation]
    private let reads = Mutex(0)
    private let actions = Mutex<[String]>([])
    /// What `pasteboardHolds` answers: whether the simulator's pasteboard holds the pasted text, `nil` for unknown.
    private let pasteboard: Bool?

    var performedActions: [String] {
        actions.withLock { $0 }
    }

    /// Readings whose only element is a heading named by the outline.
    convenience init(outlines: [String]) {
        self.init(readings: outlines.map { outline in
            Fixtures.snapshot(outline: outline, entries: [Fixtures.entry(0, outline, role: "Heading")])
        })
    }

    init(readings: [UISnapshot], pasteboard: Bool? = nil) {
        self.readings = readings.map { ScreenObservation(snapshot: $0, disappearedApps: []) }
        self.pasteboard = pasteboard
    }

    func observe() async throws -> ScreenObservation {
        reads.withLock { reads in
            defer { reads += 1 }
            return readings[min(reads, readings.count - 1)]
        }
    }

    func tap(alias: Int, on _: UISnapshot) async throws -> [String] {
        record("tap @\(alias)")
    }

    func perform(_ gesture: ElementGesture, alias: Int, on _: UISnapshot) async throws -> [String] {
        record("\(gesture.rawValue) @\(alias)")
    }

    func perform(_ action: SimUseDeviceAction, in _: ScreenSpace) async throws -> [String] {
        record("\(action)")
    }

    func paste(_ text: String, replacing: Bool) async throws -> [String] {
        record(replacing ? "paste --replace \(text)" : "paste \(text)")
    }

    func pasteboardHolds(_: String) async -> Bool? {
        pasteboard
    }

    private func record(_ action: String) -> [String] {
        actions.withLock { $0.append(action) }
        return []
    }
}

@testable import JevSimUseKit
import Synchronization

/// Returns one reading per `observe` call, in order (repeating the last): a screen that is still changing. Records
/// every action.
final class ScriptedDriver: DeviceDriving {
    private let readings: [ScreenObservation]
    private let reads = Mutex(0)
    private let actions = Mutex<[String]>([])

    var performedActions: [String] {
        actions.withLock { $0 }
    }

    /// Readings whose only element is a heading named by the outline.
    convenience init(outlines: [String]) {
        self.init(readings: outlines.map { outline in
            Fixtures.snapshot(outline: outline, entries: [Fixtures.entry(0, outline, role: "Heading")])
        })
    }

    init(readings: [UISnapshot]) {
        self.readings = readings.map { ScreenObservation(snapshot: $0, disappearedApps: []) }
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

    func perform(_ action: SimUseDeviceAction, platform _: String) async throws -> [String] {
        record("\(action)")
    }

    func paste(_ text: String) async throws -> [String] {
        record("paste \(text)")
    }

    private func record(_ action: String) -> [String] {
        actions.withLock { $0.append(action) }
        return []
    }
}

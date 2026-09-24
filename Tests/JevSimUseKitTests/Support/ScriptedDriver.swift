@testable import JevSimUseKit
import Synchronization

/// Returns one reading per `observe` call, in order (repeating the last): a screen that is still changing.
final class ScriptedDriver: DeviceDriving {
    private let readings: [ScreenObservation]
    private let reads = Mutex(0)

    init(outlines: [String]) {
        readings = outlines.map { outline in
            let snapshot = Fixtures.snapshot(outline: outline, entries: [Fixtures.entry(0, outline, role: "Heading")])
            return ScreenObservation(snapshot: snapshot, disappearedApps: [])
        }
    }

    func observe() async throws -> ScreenObservation {
        reads.withLock { reads in
            defer { reads += 1 }
            return readings[min(reads, readings.count - 1)]
        }
    }

    func tap(alias _: Int, on _: UISnapshot) async throws -> [String] {
        []
    }

    func perform(_: ElementGesture, alias _: Int, on _: UISnapshot) async throws -> [String] {
        []
    }

    func perform(_: SimUseDeviceAction, platform _: String) async throws -> [String] {
        []
    }

    func paste(_: String) async throws -> [String] {
        []
    }
}

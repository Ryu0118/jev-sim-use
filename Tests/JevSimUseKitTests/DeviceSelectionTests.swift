import Foundation
@testable import JevSimUseKit
import Testing

/// Which device a run pins. Several devices, none, and a requested id missing from the quick list run end to end in
/// scripts/e2e.sh; this is every case of the choice itself.
@Suite("A run pins the requested device or the only usable one, and never guesses")
struct DeviceSelectionTests {
    private static func device(_ json: String) -> SimUseDevice {
        (try? JSONDecoder().decode(SimUseDevice.self, from: Data(json.utf8)))
            ?? SimUseDevice(deviceId: "", name: "", platform: "", kind: nil, state: "")
    }

    private static let simulator = device(Fixtures.simulator)
    private static let emulator = device(Fixtures.emulator)
    private static let physical = device(Fixtures.physicalIPhone)

    @Test("selects or refuses", arguments: [
        ("the only simulator, beside a physical iPhone it cannot drive", String?.none, [simulator, physical],
         Result<String, SimUseError>.success(simulator.deviceId)),
        ("the requested device", emulator.deviceId, [simulator, emulator], .success(emulator.deviceId)),
        ("several usable devices", nil, [simulator, emulator], .failure(.multipleDevices([simulator, emulator]))),
        ("no device", nil, [], .failure(.noDevice)),
        ("only a physical iPhone", nil, [physical], .failure(.noDevice)),
        ("a requested device that is not there", "missing", [simulator], .failure(.commandFailed(
            arguments: ["devices"], message: "device missing is not booted or connected",
            hint: "List candidates with `sim-use devices --all`.",
        ))),
        ("a requested physical iPhone", physical.deviceId, [physical], .failure(.commandFailed(
            arguments: ["devices"], message: "physical iOS devices are not supported",
            hint: "sim-use offers only ui, tap by id/label, and screenshot on physical iOS.",
        ))),
    ] as [(String, String?, [SimUseDevice], Result<String, SimUseError>)])
    func select(_: String, requested: String?, devices: [SimUseDevice], expected: Result<String, SimUseError>) {
        let result = Result { try DeviceSelection.select(requested, from: devices).deviceId }
        #expect(result.mapError { $0 as? SimUseError ?? .noDevice } == expected)
    }
}

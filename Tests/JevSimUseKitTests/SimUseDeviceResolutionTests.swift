@testable import JevSimUseKit
import Testing

struct SimUseDeviceResolutionTests {
    @Test("prefers the flag, then SIM_USE_DEVICE, then lets sim-use pick", arguments: [
        ("A", ["SIM_USE_DEVICE": "B"], "A"),
        (nil, ["SIM_USE_DEVICE": "B"], "B"),
        (nil, ["SIM_USE_DEVICE": ""], nil),
    ] as [(String?, [String: String], String?)])
    func resolution(flag: String?, environment: [String: String], expected: String?) {
        #expect(SimUseBootstrap.deviceID(flag: flag, environment: environment) == expected)
    }
}

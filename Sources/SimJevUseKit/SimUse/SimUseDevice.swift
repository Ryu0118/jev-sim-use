/// One entry of `sim-use devices --json`.
package struct SimUseDevice: Decodable, Sendable, Hashable {
    /// The id to pass as `--device`.
    package let deviceId: String
    /// Human-readable device name.
    package let name: String
    /// `ios` or `android`.
    package let platform: String
    /// `simulator`, `emulator`, or `physical`. Absent before sim-use 0.14.0.
    package let kind: String?
    /// Free-form state such as `Booted` or `device`.
    package let state: String

    /// sim-use supports only a few verbs on physical iPhones, so the agent cannot drive them.
    package var isPhysicalIOS: Bool {
        platform == "ios" && kind == "physical"
    }
}

/// The `data` payload of `sim-use devices --json`.
struct DeviceListPayload: Decodable, Sendable {
    let devices: [SimUseDevice]
}

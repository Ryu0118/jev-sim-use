/// One entry of `sim-use devices --json`.
public struct SimUseDevice: Decodable, Sendable, Hashable {
    /// The id to pass as `--device`.
    public let deviceId: String
    /// Human-readable device name.
    public let name: String
    /// `ios` or `android`.
    public let platform: String
    /// `simulator`, `emulator`, or `physical`. Absent before sim-use 0.14.0.
    public let kind: String?
    /// Free-form state such as `Booted` or `device`.
    public let state: String

    /// sim-use supports only a few verbs on physical iPhones, so the agent cannot drive them.
    public var isPhysicalIOS: Bool {
        platform == "ios" && kind == "physical"
    }
}

/// The `data` payload of `sim-use devices --json`.
struct DeviceListPayload: Decodable, Sendable {
    let devices: [SimUseDevice]
}

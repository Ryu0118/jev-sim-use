/// Picks the device to pin from `sim-use devices` output.
enum DeviceSelection {
    /// Physical iOS devices are never auto-picked, matching sim-use's own resolver.
    static func select(_ requestedID: String?, from devices: [SimUseDevice]) throws -> SimUseDevice {
        if let requestedID {
            guard let device = devices.first(where: { $0.deviceId == requestedID }) else {
                throw SimUseError.commandFailed(
                    arguments: ["devices"],
                    message: "device \(requestedID) is not booted or connected",
                    hint: "List candidates with `sim-use devices --all`.",
                )
            }
            guard !device.isPhysicalIOS else {
                throw SimUseError.commandFailed(
                    arguments: ["devices"],
                    message: "physical iOS devices are not supported",
                    hint: "sim-use offers only ui, tap by id/label, and screenshot on physical iOS.",
                )
            }
            return device
        }
        let candidates = devices.filter { !$0.isPhysicalIOS }
        switch candidates.count {
        case 0: throw SimUseError.noDevice
        case 1: return candidates[0]
        default: throw SimUseError.multipleDevices(candidates)
        }
    }
}

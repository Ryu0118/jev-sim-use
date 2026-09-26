/// A hardware button sim-use can press; the raw value is the `sim-use button` argument. `back` is not listed: going
/// back is `SimUseDeviceAction.goBack`.
package enum HardwareButton: String, Sendable, Hashable, CaseIterable {
    case home
    case lock
    case recents
    case applePay = "apple-pay"
    case sideButton = "side-button"
    case siri

    /// The buttons offered on `platform`, from those `sim-use button --help` lists. Siri stays reachable through `exec`
    /// only: one press left `sim-use ui` unable to read the simulator, even after Home and a daemon restart, until the
    /// simulator was rebooted.
    static func available(on platform: String) -> [HardwareButton] {
        platform == SimUseContract.Platform.android ? [.home, .lock, .recents] : [.home, .lock, .applePay, .sideButton]
    }
}

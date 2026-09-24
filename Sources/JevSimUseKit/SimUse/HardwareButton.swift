/// A hardware button sim-use can press; the raw value is the `sim-use button` argument. `back` is not listed: going
/// back is `SimUseDeviceAction.goBack`.
package enum HardwareButton: String, Sendable, Hashable, CaseIterable {
    case home
    case lock
    case recents
    case applePay = "apple-pay"
    case sideButton = "side-button"
    case siri

    /// The buttons sim-use supports on `platform`, per `sim-use button --help`.
    static func available(on platform: String) -> [HardwareButton] {
        platform == SimUseContract.Platform.android ? [.home, .lock, .recents] : [.home, .lock, .applePay, .sideButton, .siri]
    }
}

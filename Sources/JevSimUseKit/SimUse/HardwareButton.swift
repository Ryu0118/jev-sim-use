/// A hardware button sim-use can press. `back` is not listed: going back is `SimUseDeviceAction.goBack`.
package enum HardwareButton: String, Sendable, Hashable, CaseIterable {
    case home
    case lock
    case recents
    case applePay = "apple-pay"
    case sideButton = "side-button"
    case siri

    /// The buttons sim-use supports on `platform`, per `sim-use button --help`.
    static func available(on platform: String) -> [HardwareButton] {
        platform == "android" ? [.home, .lock, .recents] : [.home, .lock, .applePay, .sideButton, .siri]
    }

    /// The `sim-use button` argument.
    var argument: String {
        switch self {
        case .home: SimUseContract.Button.home
        case .lock: SimUseContract.Button.lock
        case .recents: SimUseContract.Button.recents
        case .applePay: SimUseContract.Button.applePay
        case .sideButton: SimUseContract.Button.sideButton
        case .siri: SimUseContract.Button.siri
        }
    }
}

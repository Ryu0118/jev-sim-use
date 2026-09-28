/// Why no screen-change watcher could be opened or a private message failed. The run then reads the screen by
/// polling, as it does without a watcher.
package enum ScreenWatchError: Error, Equatable, Sendable, CustomStringConvertible {
    /// Turned off with `JEV_SIM_USE_SCREEN_WATCH=0`.
    case disabled
    /// The device is not an iOS simulator.
    case notASimulator(String)
    /// Neither `DEVELOPER_DIR` nor `xcode-select -p` named a developer directory.
    case developerDirectoryUnknown
    /// The private framework is not installed.
    case frameworkMissing(path: String)
    /// The private framework no longer has the class.
    case classMissing(String)
    /// An object no longer answers the selector.
    case selectorMissing(String)
    /// An object answers the selector with another signature than the one this tool was written against.
    case unexpectedSignature(String)
    /// The message raised an Objective-C exception.
    case raised(selector: String, reason: String)
    /// The message answered nothing, or not the kind of object expected.
    case noResult(String)
    /// CoreSimulator does not know the device.
    case deviceNotFound(String)
    /// The device is not booted.
    case deviceNotBooted(String)
    /// The device has no display of class 0, its own screen.
    case noMainDisplay

    /// A short reason, for the debug note.
    package var description: String {
        switch self {
        case .disabled: "turned off"
        case let .notASimulator(id): "\(id) is not an iOS simulator"
        case .developerDirectoryUnknown: "no developer directory (DEVELOPER_DIR, xcode-select -p)"
        case let .frameworkMissing(path): "\(path) could not be loaded"
        case let .classMissing(name): "class \(name) is missing"
        case let .selectorMissing(selector): "\(selector) is not answered"
        case let .unexpectedSignature(selector): "\(selector) has an unexpected signature"
        case let .raised(selector, reason): "\(selector) raised: \(reason)"
        case let .noResult(selector): "\(selector) answered nothing usable"
        case let .deviceNotFound(id): "CoreSimulator does not know \(id)"
        case let .deviceNotBooted(id): "\(id) is not booted"
        case .noMainDisplay: "no main display"
        }
    }
}

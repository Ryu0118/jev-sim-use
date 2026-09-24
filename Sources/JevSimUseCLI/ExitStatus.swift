import JevSimUseKit

/// Exit statuses beyond 0 (goal reached) and 1 (goal not reached).
enum ExitStatus {
    /// Something to fix before running: missing tool, device, key, or bad configuration.
    static let setup: Int32 = 2
    /// sim-use or Jev failed while running.
    static let runtime: Int32 = 3

    static func of(_ error: any Error) -> Int32 {
        switch error {
        case is JevSettingsError: setup
        case let error as SimUseError where error.isSetupProblem: setup
        default: runtime
        }
    }
}

extension SimUseError {
    var isSetupProblem: Bool {
        switch self {
        case .notInstalled, .unreadableVersion, .outdated, .noDevice, .multipleDevices: true
        case .commandFailed, .malformedOutput: false
        }
    }
}

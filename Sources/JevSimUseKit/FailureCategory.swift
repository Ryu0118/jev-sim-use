/// Whether a failure is something to fix before running, or went wrong while running.
package enum FailureCategory: Sendable, Equatable {
    /// Missing tool, device, key, or bad configuration.
    case setup
    /// sim-use or Jev failed while running.
    case runtime

    /// Classifies any error thrown by a Runner.
    package init(_ error: any Error) {
        switch error {
        case is JevSettingsError, is SessionStoreError: self = .setup
        case let error as SimUseError where error.isSetupProblem: self = .setup
        default: self = .runtime
        }
    }
}

extension SimUseError {
    /// Whether the user must change their environment before retrying.
    var isSetupProblem: Bool {
        switch self {
        case .notInstalled, .unreadableVersion, .outdated, .noDevice, .multipleDevices: true
        case .commandFailed, .malformedOutput: false
        }
    }
}

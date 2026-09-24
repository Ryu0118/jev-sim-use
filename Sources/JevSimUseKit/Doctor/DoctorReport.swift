/// The result of one readiness check.
package enum DoctorCheckStatus: Sendable, Equatable {
    /// Ready, with a detail such as the version or device.
    case passed(String)
    /// Not ready, with the reason and how to fix it.
    case failed(String)
    /// Not attempted because an earlier check failed.
    case skipped(String)
}

/// One named readiness check.
package struct DoctorCheck: Sendable, Equatable {
    /// `sim-use`, `device`, or `jev`.
    package let name: String
    /// What the check found.
    package let status: DoctorCheckStatus
}

/// Everything `doctor` found.
package struct DoctorReport: Sendable, Equatable {
    /// Checks in the order they ran.
    package let checks: [DoctorCheck]

    /// Whether every check passed.
    package var isHealthy: Bool {
        checks.allSatisfy {
            if case .passed = $0.status {
                true
            } else {
                false
            }
        }
    }
}

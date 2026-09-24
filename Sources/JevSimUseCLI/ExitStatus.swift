import JevSimUseKit

/// Exit statuses beyond 0 (goal reached) and 1 (goal not reached); 64 comes from ArgumentParser.
enum ExitStatus {
    /// Something to fix before running: missing tool, device, key, or bad configuration.
    static let setup: Int32 = 2
    /// sim-use or Jev failed while running.
    static let runtime: Int32 = 3

    static func of(_ error: any Error) -> Int32 {
        switch FailureCategory(error) {
        case .setup: setup
        case .runtime: runtime
        }
    }
}

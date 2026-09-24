import Foundation

/// Everything a command takes from the outside world. The live value is the only place the CLI reads
/// `ProcessInfo`; tests pass their own.
package struct CLIContext: Sendable {
    /// Where the command writes.
    package var output: CLIOutput
    /// The process environment.
    package var environment: [String: String]

    /// The real process output and environment.
    package static var live: CLIContext {
        CLIContext(output: .live, environment: ProcessInfo.processInfo.environment)
    }

    package init(output: CLIOutput, environment: [String: String]) {
        self.output = output
        self.environment = environment
    }
}

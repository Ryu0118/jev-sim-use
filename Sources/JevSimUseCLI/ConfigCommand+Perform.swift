import ArgumentParser
import JevSimUseKit

extension ConfigCommand {
    /// Runs `operation` against the user's config file and presents the outcome.
    static func perform(_ operation: ConfigOperation, context: CLIContext) throws {
        let runner = ConfigRunner(store: UserConfigStore(environment: context.environment))
        switch try runner.run(operation) {
        case let .value(value?):
            context.output.standardOutput(value)
        case .value(nil):
            throw ExitCode.failure
        case let .entries(entries):
            entries.forEach { context.output.standardOutput("\($0.key.rawValue)=\($0.value)") }
        case .updated:
            break
        }
    }
}

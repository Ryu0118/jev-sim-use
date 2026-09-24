import ArgumentParser
import SimJevUseKit

extension ConfigCommand {
    struct Get: ContextualCommand {
        static let configuration = CommandConfiguration(abstract: "Print a stored value.")

        @Argument(help: "The key to read.") var key: UserConfig.Key

        func run(context: CLIContext) async throws {
            guard let value = try UserConfigStore(environment: context.environment).load()[key] else { throw ExitCode.failure }
            context.output.standardOutput(value)
        }
    }

    struct Set: ContextualCommand {
        static let configuration = CommandConfiguration(abstract: "Store a value.")

        @Argument(help: "The key to write.") var key: UserConfig.Key
        @Argument(help: "The value. base-url must be HTTPS, or HTTP on localhost.") var value: String

        func validate() throws {
            guard key == .baseURL else { return }
            do {
                _ = try JevSettings.validateBaseURL(value)
            } catch {
                throw ValidationError(error.description)
            }
        }

        func run(context: CLIContext) async throws {
            try ConfigCommand.update(environment: context.environment) { $0[key] = value }
        }
    }

    struct Unset: ContextualCommand {
        static let configuration = CommandConfiguration(abstract: "Remove a stored value.")

        @Argument(help: "The key to remove.") var key: UserConfig.Key

        func run(context: CLIContext) async throws {
            try ConfigCommand.update(environment: context.environment) { $0[key] = nil }
        }
    }

    struct List: ContextualCommand {
        static let configuration = CommandConfiguration(abstract: "Print all stored values.")

        func run(context: CLIContext) async throws {
            let config = try UserConfigStore(environment: context.environment).load()
            for key in UserConfig.Key.allCases {
                if let value = config[key] {
                    context.output.standardOutput("\(key.rawValue)=\(value)")
                }
            }
        }
    }

    static func update(environment: [String: String], _ change: (inout UserConfig) -> Void) throws {
        let store = UserConfigStore(environment: environment)
        var config = try store.load()
        change(&config)
        try store.save(config)
    }
}

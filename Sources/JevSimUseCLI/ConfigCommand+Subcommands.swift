import ArgumentParser
import JevSimUseKit

extension ConfigCommand {
    struct Get: ContextualCommand {
        static let configuration = CommandConfiguration(abstract: "Print a stored value; exits 1 when it is not set.")

        @Argument(help: "The key to read.") var key: UserConfig.Key

        func run(context: CLIContext) async throws {
            try ConfigCommand.perform(.get(key), context: context)
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
            try ConfigCommand.perform(.set(key, value), context: context)
        }
    }

    struct Unset: ContextualCommand {
        static let configuration = CommandConfiguration(abstract: "Remove a stored value.")

        @Argument(help: "The key to remove.") var key: UserConfig.Key

        func run(context: CLIContext) async throws {
            try ConfigCommand.perform(.unset(key), context: context)
        }
    }

    struct List: ContextualCommand {
        static let configuration = CommandConfiguration(abstract: "Print all stored values.")

        func run(context: CLIContext) async throws {
            try ConfigCommand.perform(.list, context: context)
        }
    }
}

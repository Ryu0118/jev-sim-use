import ArgumentParser
import SimJevUseKit

extension ConfigCommand {
    struct Get: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Print a stored value.")

        @Argument(help: "The key to read.") var key: UserConfig.Key

        func run() throws {
            guard let value = try UserConfigStore().load()[key] else { throw ExitCode.failure }
            print(value)
        }
    }

    struct Set: ParsableCommand {
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

        func run() throws {
            try ConfigCommand.update { $0[key] = value }
        }
    }

    struct Unset: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Remove a stored value.")

        @Argument(help: "The key to remove.") var key: UserConfig.Key

        func run() throws {
            try ConfigCommand.update { $0[key] = nil }
        }
    }

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Print all stored values.")

        func run() throws {
            let config = try UserConfigStore().load()
            for key in UserConfig.Key.allCases {
                if let value = config[key] {
                    print("\(key.rawValue)=\(value)")
                }
            }
        }
    }

    static func update(_ change: (inout UserConfig) -> Void) throws {
        let store = UserConfigStore()
        var config = try store.load()
        change(&config)
        try store.save(config)
    }
}

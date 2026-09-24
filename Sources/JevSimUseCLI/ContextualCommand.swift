import ArgumentParser

/// A command whose body receives a `CLIContext`, so tests can run it with recorded output.
protocol ContextualCommand: AsyncParsableCommand {
    /// Runs the command against `context`.
    func run(context: CLIContext) async throws
}

extension ContextualCommand {
    func run() async throws {
        try await run(context: .live)
    }
}

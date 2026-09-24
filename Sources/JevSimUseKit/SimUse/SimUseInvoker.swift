import Foundation

/// Runs one `sim-use` command in `--json` mode and decodes its envelope.
struct SimUseInvoker: Sendable {
    let executable: URL
    let runner: any CommandRunning

    /// Handles both failure shapes: an error envelope on stdout (exit 1), and plain
    /// text on stderr with an empty stdout (argument validation, exit 64).
    ///
    /// `operands` go after a `--` terminator, so user text such as `-5` is never parsed as an option.
    func invoke<Payload: Decodable & Sendable>(
        _ arguments: [String],
        operands: [String] = [],
        as _: Payload.Type = Payload.self,
    ) async throws -> SimUseEnvelope<Payload> {
        let fullArguments = arguments + ["--json"] + (operands.isEmpty ? [] : ["--"] + operands)
        let output = try await runner.run(executable, arguments: fullArguments)
        let envelope = try? JSONDecoder().decode(SimUseEnvelope<Payload>.self, from: output.stdout)
        guard let envelope else {
            let stderr = output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = stderr.isEmpty ? "exit status \(output.exitCode) with no JSON output" : stderr
            throw SimUseError.malformedOutput(arguments: arguments, detail: detail)
        }
        guard envelope.succeeded else {
            throw SimUseError.commandFailed(
                arguments: arguments, message: envelope.error ?? "unknown error", hint: envelope.hint,
            )
        }
        return envelope
    }
}

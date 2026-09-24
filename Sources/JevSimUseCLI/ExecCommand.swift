import ArgumentParser
import Foundation
import JevSimUseKit

struct ExecCommand: ContextualCommand {
    static let configuration = CommandConfiguration(
        commandName: "exec",
        abstract: "Run a sim-use command as-is (e.g. `jev-sim-use exec ui`).",
        discussion: "Replaces this process with sim-use, so output, TTY, signals, and exit status are sim-use's own.",
    )

    @Argument(parsing: .captureForPassthrough, help: "Arguments passed to sim-use unchanged.")
    var arguments: [String] = []

    func run(context: CLIContext) async throws {
        let executable: URL
        do {
            let bootstrap = SimUseBootstrap(locator: ExecutableLocator(environment: context.environment))
            executable = try await bootstrap.verifyInstallation().executable
        } catch {
            throw context.failure(error)
        }
        let path = executable.path(percentEncoded: false)
        let argv = ([path] + arguments).map { strdup($0) } + [nil]
        execv(path, argv)
        // execv returns only on failure.
        context.output.standardError("Error: could not run \(path): \(String(cString: strerror(errno)))")
        throw ExitCode(ExitStatus.runtime)
    }
}

import ArgumentParser
import JevSimUseKit

extension RunGoalRequest {
    /// Runs this request with the live dependencies. Progress goes to stderr; stdout carries only the final
    /// outcome and, when the goal was not reached, the session id to resume, which is what a supervising agent reads.
    func perform(context: CLIContext) async throws {
        let runner = RunGoalRunner(
            bootstrap: SimUseBootstrap(locator: ExecutableLocator(environment: context.environment)),
            configStore: UserConfigStore(environment: context.environment),
            sessionStore: SessionStore(environment: context.environment),
            environment: context.environment,
        )
        let result: RunGoalOutcome
        do {
            result = try await runner.run(self) { context.output.standardError($0.description) }
        } catch {
            throw context.failure(error)
        }
        context.output.standardOutput("\(result.outcome)")
        guard !result.outcome.isSuccess else { return }
        context.output.standardOutput("Session: \(result.sessionID)")
        throw ExitCode.failure
    }
}

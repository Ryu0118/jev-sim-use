import ArgumentParser

extension CLIContext {
    /// Reports a Runner's `error` on stderr and returns the exit code for its `FailureCategory`, for the caller to throw.
    func failure(_ error: any Error) -> ExitCode {
        output.standardError("Error: \(error)")
        return ExitCode(ExitStatus.of(error))
    }
}

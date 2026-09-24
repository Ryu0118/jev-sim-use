import ArgumentParser

/// Runs a command body and returns the exit status it would end the process with.
enum ExitStatusCapture {
    static func status(_ body: () async throws -> Void) async throws -> Int32 {
        do {
            try await body()
            return 0
        } catch let exit as ExitCode {
            return exit.rawValue
        }
    }
}

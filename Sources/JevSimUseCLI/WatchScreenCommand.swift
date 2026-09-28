import ArgumentParser
import Foundation
import JevSimUseKit

/// A hidden probe: prints the time of each change of a simulator's screen image, to measure how soon a change shows.
struct WatchScreenCommand: ContextualCommand {
    static let configuration = CommandConfiguration(
        commandName: "watch-screen",
        abstract: "Print the Unix time of each change of a simulator's screen image (status bar aside).",
        shouldDisplay: false,
    )

    @Option(help: "The booted iOS simulator's UDID.")
    var device: String

    @Option(help: "How long to watch, in seconds.")
    var seconds: Double = 10

    func run(context: CLIContext) async throws {
        do {
            try await ScreenWatchProbeRunner(environment: context.environment).run(
                simulatorID: device, for: .milliseconds(Int(seconds * 1000)),
            ) { date in
                context.output.standardOutput("changed \(date.timeIntervalSince1970.formatted(.number.precision(.fractionLength(3)).grouping(.never)))")
            }
        } catch {
            context.output.standardError("Error: no screen-change watcher: \(error)")
            throw ExitCode(ExitStatus.setup)
        }
    }
}

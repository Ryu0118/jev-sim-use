import ArgumentParser
import SimJevUseKit

@main
struct SimJevUseCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "SimJevUse",
        abstract: "Drive an iOS Simulator or Android device toward a goal, with Jev choosing each action via sim-use.",
        version: SimJevUseVersion.current,
        subcommands: [RunCommand.self, DoctorCommand.self],
        defaultSubcommand: RunCommand.self,
    )
}

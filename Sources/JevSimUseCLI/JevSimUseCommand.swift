import ArgumentParser
import SimJevUseKit

/// The root `sim-jev-use` command.
package struct SimJevUseCommand: AsyncParsableCommand {
    package static let configuration = CommandConfiguration(
        commandName: "sim-jev-use",
        abstract: "Drive an iOS Simulator or Android device toward a goal, with Jev choosing each action via sim-use.",
        discussion: """
        Exit status: 0 goal reached, 1 goal not reached, 2 setup error, 3 sim-use or Jev failure, \
        64 invalid arguments.
        """,
        version: SimJevUseVersion.current,
        subcommands: [RunCommand.self, ExecCommand.self, DoctorCommand.self, ConfigCommand.self],
        defaultSubcommand: RunCommand.self,
    )

    package init() {}
}

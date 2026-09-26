import ArgumentParser
import JevSimUseKit

/// The root `jev-sim-use` command.
package struct JevSimUseCommand: AsyncParsableCommand {
    /// Subcommands, version, and help text; `run` is the default so a bare goal works.
    package static let configuration = CommandConfiguration(
        commandName: "jev-sim-use",
        abstract: "Drive an iOS Simulator or Android device toward a goal, with Jev choosing each action via sim-use.",
        discussion: """
        AI agents: read the jev-sim-use skill before the first run. `jev-sim-use skill print` prints it; \
        `jev-sim-use skill install --client claude|agents` installs it.

        Exit status: 0 goal reached, 1 goal not reached, 2 setup error, 3 sim-use or Jev failure, \
        64 invalid arguments.
        """,
        version: JevSimUseVersion.current,
        subcommands: [
            RunCommand.self, SessionCommand.self, ExecCommand.self, DoctorCommand.self, ConfigCommand.self,
            SkillCommand.self,
        ],
        defaultSubcommand: RunCommand.self,
    )

    package init() {}
}

import ArgumentParser
import SimJevUseKit

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Read or change persistent settings (base-url, model).",
        discussion: """
        Stored in $XDG_CONFIG_HOME/sim-jev-use/config.json (default ~/.config). \
        The API key is never stored; set TYPESAFE_API_KEY.
        """,
        subcommands: [Get.self, Set.self, Unset.self, List.self],
    )
}

extension UserConfig.Key: ExpressibleByArgument {}

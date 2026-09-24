/// Every name this tool passes to the sim-use CLI, in one place.
///
/// sim-use's CLI is the only interface it treats as stable, so these strings are the whole contract. The contract
/// test (`mise run contract-test`) checks each one against the installed sim-use's `--help`.
package enum SimUseContract {
    /// The executable looked up on `PATH`.
    static let executable = "sim-use"
    static let versionFlag = "--version"
    static let jsonFlag = "--json"
    static let deviceFlag = "--device"
    static let noRawFlag = "--no-raw"
    /// Ends option parsing, so user text such as `-5` is never read as a flag.
    static let operandTerminator = "--"

    /// Subcommands.
    enum Command {
        static let ui = "ui"
        static let devices = "devices"
        static let tap = "tap"
        static let gesture = "gesture"
        static let button = "button"
        static let paste = "paste"
    }

    /// Gesture presets, named by finger direction: `scroll-up` pages down.
    enum Gesture {
        static let scrollUp = "scroll-up"
        static let scrollDown = "scroll-down"
        static let swipeFromLeftEdge = "swipe-from-left-edge"
    }

    /// Hardware buttons.
    enum Button {
        static let back = "back"
    }
}

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

    /// Values of the `platform` field in sim-use's JSON.
    enum Platform {
        static let ios = "ios"
        static let android = "android"
    }

    /// Subcommands.
    enum Command {
        static let ui = "ui"
        static let devices = "devices"
        static let tap = "tap"
        static let gesture = "gesture"
        static let button = "button"
        static let paste = "paste"
        static let longPress = "long-press"
        static let swipe = "swipe"
        static let keyboardState = "keyboard-state"
        /// `ios key`: press one HID key on an iOS simulator.
        static let iosKey = ["ios", "key"]
        static let type = "type"
    }

    /// Return, which submits a search field or a form.
    enum Key {
        /// USB HID usage 0x28, as `sim-use ios key --help` lists it.
        static let returnKeycode = "40"
        /// Android has no `key` verb; its `type` help says to embed a newline for Enter.
        static let newline = "\n"
    }

    /// `tap` options for a coordinate tap that is held briefly.
    enum Tap {
        static let x = "-x"
        static let y = "-y"
        static let duration = "--duration"
        /// Selectors that find the element in a fresh accessibility read, for when the cached alias is stale.
        static let id = "--id"
        static let label = "--label"
        /// sim-use's help: UISwitch (`CheckBox`) ignores zero-duration taps; hold for 0.05 s.
        static let switchHoldSeconds = "0.05"
    }

    /// `swipe` endpoints, as `x,y` in the coordinates describe-ui reports.
    enum Swipe {
        static let from = "--from"
        static let to = "--to"
    }

    /// Gesture presets, named by finger direction: `scroll-up` pages down.
    enum Gesture {
        static let scrollUp = "scroll-up"
        static let scrollDown = "scroll-down"
        static let scrollLeft = "scroll-left"
        static let scrollRight = "scroll-right"
        static let swipeFromLeftEdge = "swipe-from-left-edge"
        static let swipeFromRightEdge = "swipe-from-right-edge"
        static let pinchIn = "pinch-in"
        static let pinchOut = "pinch-out"
        static let rotateClockwise = "rotate-cw"
        static let rotateCounterclockwise = "rotate-ccw"
        /// Pivot of a two-finger preset. On iOS these are device-native portrait points, the space describe-ui uses.
        static let centerX = "--center-x"
        static let centerY = "--center-y"
        static let duration = "--duration"
        /// Duration that makes a sideways scroll turn one page.
        static let sidewaysSeconds = "0.3"
    }

    /// Hardware buttons. `back` is how Android goes back; the others are `HardwareButton` raw values.
    enum Button {
        static let back = "back"
    }
}

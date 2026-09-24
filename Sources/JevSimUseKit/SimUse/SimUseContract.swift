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
        static let longPress = "long-press"
        static let swipe = "swipe"
    }

    /// `tap` options for a coordinate tap that is held briefly.
    enum Tap {
        static let x = "-x"
        static let y = "-y"
        static let duration = "--duration"
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
        static let scale = "--scale"
        static let angle = "--angle"
        static let duration = "--duration"
        /// Duration that makes a sideways scroll turn one page.
        static let sidewaysSeconds = "0.3"
    }

    /// Hardware buttons. iOS has home, lock, apple-pay, side-button, and siri; Android has home, back, lock, and
    /// recents.
    enum Button {
        static let home = "home"
        static let lock = "lock"
        static let back = "back"
        static let recents = "recents"
        static let applePay = "apple-pay"
        static let sideButton = "side-button"
        static let siri = "siri"
    }
}

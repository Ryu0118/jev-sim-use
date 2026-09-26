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
    /// Skips discovering physical iPhones for `devices`, which this tool never drives; the discovery took about a second.
    static let noPhysicalIOSFlag = "--no-physical-ios"
    /// Runs a command in-process instead of through sim-use's per-device daemon. An iOS tap took 0.2 s this way and
    /// 0.4 s through the daemon, which checks for crashed apps on every command. The daemon still reports an app that
    /// disappeared on its next command, which is always the `ui` read after a tap.
    static let noDaemonEnvironment = ["SIM_USE_NO_DAEMON": "1"]
    /// Ends option parsing, so user text such as `-5` is never read as a flag.
    static let operandTerminator = "--"

    /// The advisory kind sim-use attaches when it could not confirm the screen's orientation and assumed one.
    static let orientationFallback = "orientation_calibration_fallback"

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
        static let daemon = "daemon"
        /// `ios key`: press one HID key on an iOS simulator.
        static let iosKey = ["ios", "key"]
        static let type = "type"
    }

    /// `daemon stop`, which ends the per-device daemon; the next command through the daemon starts a fresh one.
    enum Daemon {
        static let stop = "stop"
        static let timeout = "--timeout"
        /// Seconds per stop step (cooperative, then SIGTERM). The default 2 s made a stop of an unresponsive daemon take
        /// 6 s; the reading after it does not need the daemon gone.
        static let stopSeconds = "1"
    }

    /// Return, which submits a search field or a form.
    enum Key {
        /// USB HID usage 0x28, as `sim-use ios key --help` lists it.
        static let returnKeycode = "40"
        /// USB HID usage 0x29. `ios key --help` does not list it; it closed a sheet and a context menu on iOS 26.
        static let escapeKeycode = "41"
        /// Android has no `key` verb; its `type` help says to embed a newline for Enter.
        static let newline = "\n"
    }

    /// `tap` options for a coordinate tap that is held briefly.
    enum Tap {
        static let x = "-x"
        static let y = "-y"
        static let duration = "--duration"
        /// sim-use's help: UISwitch (`CheckBox`) ignores zero-duration taps; hold for 0.05 s.
        static let switchHoldSeconds = "0.05"
    }

    /// `paste` options.
    enum Paste {
        /// Selects all (Cmd+A) before pasting, so the paste replaces the field's content.
        static let replace = "--replace"
    }

    /// `multi-touch`: two fingers down together, moved in a straight line, lifted together.
    enum MultiTouch {
        static let command = "multi-touch"
        static let flags = ["--x1", "--y1", "--x2", "--y2", "--x1-end", "--y1-end", "--x2-end", "--y2-end"]
        static let duration = "--duration"
        /// Half the gap between the fingers, in points.
        static let fingerOffset = 20.0

        /// Two fingers side by side at `centerX`, moved from `from` to `to` down the screen as `space` shows it, over
        /// 0.8 s.
        static func arguments(centerX: Double, from: Double, to: Double, in space: ScreenSpace) -> [String] {
            let left = centerX - fingerOffset, right = centerX + fingerOffset
            let points = [(left, from), (right, from), (left, to), (right, to)].map { space.native(x: $0.0, y: $0.1) }
            let values = points.flatMap { [$0.x, $0.y] }.map { "\($0)" }
            return [command] + zip(flags, values).flatMap { [$0, $1] } + [duration, "0.8"]
        }
    }

    /// `swipe` endpoints, as `x,y` in device-native points (see `ScreenSpace`).
    enum Swipe {
        static let from = "--from"
        static let to = "--to"

        /// A swipe between two device-native points.
        static func arguments(from start: (x: Double, y: Double), to end: (x: Double, y: Double)) -> [String] {
            [Command.swipe, from, "\(start.x),\(start.y)", to, "\(end.x),\(end.y)"]
        }

        static let duration = "--duration"
        /// Fast enough for a pull to refresh; the scroll preset's 1.5 s is not.
        static let refreshSeconds = "0.3"
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
        /// Pivot of a two-finger preset, in device-native points (see `ScreenSpace`).
        static let centerX = "--center-x"
        static let centerY = "--center-y"
        static let duration = "--duration"
        /// Duration that makes a sideways scroll turn one page.
        static let sidewaysSeconds = "0.3"
        static let verticalSeconds = "1.5"
    }

    /// Hardware buttons. `back` is how Android goes back; the others are `HardwareButton` raw values.
    enum Button {
        static let back = "back"
    }
}

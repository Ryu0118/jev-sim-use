extension SimUseError: CustomStringConvertible {
    static let installCommand = "brew tap lycorp-jp/tap && brew install lycorp-jp/tap/sim-use"
    static let upgradeCommand = "brew update && brew upgrade lycorp-jp/tap/sim-use"
    /// Unparseable output usually means sim-use's CLI changed under this tool.
    static let contractHint = "sim-use's CLI may have changed. Check `jev-sim-use exec --version` "
        + "(tested with \(SimUseBootstrap.testedVersion)) and run `mise run contract-test`."

    /// A message that says what went wrong and how to fix it.
    package var description: String {
        switch self {
        case let .notInstalled(searchedPath):
            """
            sim-use was not found on PATH. Install it first:
              \(Self.installCommand)
            (On Homebrew 6.0.5+ run `brew trust lycorp-jp/tap` first if the tap is reported as untrusted.)
            If it is installed, make sure its directory (e.g. /opt/homebrew/bin) is on the PATH of this process.
            Searched PATH: \(searchedPath.isEmpty ? "(empty)" : searchedPath)
            """
        case let .unreadableVersion(output):
            "Could not read the sim-use version from `sim-use --version`: \(output)"
        case let .outdated(found, minimum):
            "sim-use \(found) is too old; \(minimum) or newer is required. Upgrade with:\n  \(Self.upgradeCommand)"
        case .noDevice:
            "No booted simulator or connected device was found. Boot one, or list them with `sim-use devices --all`."
        case let .multipleDevices(devices):
            "Multiple devices are available; pass --device with one of:\n"
                + devices.map { "  \($0.deviceId)  \($0.name) (\($0.platform))" }.joined(separator: "\n")
        case let .commandFailed(arguments, message, hint):
            "`sim-use \(arguments.joined(separator: " "))` failed: \(message)" + (hint.map { "\nHint: \($0)" } ?? "")
        case .hardwareKeyboardRequired:
            """
            Entering text needs a hardware keyboard: the simulator shows only the software keyboard, and it drops \
            sim-use's paste. In Simulator, turn on I/O > Keyboard > Connect Hardware Keyboard, then run \
            `jev-sim-use session resume`.
            """
        case let .malformedOutput(arguments, detail):
            "`sim-use \(arguments.joined(separator: " "))` produced unexpected output: \(detail)\nHint: \(Self.contractHint)"
        case let .readTimedOut(deviceID, seconds):
            """
            `sim-use ui` gave no answer within \(seconds.formatted()) s, after its daemon had already been replaced \
            \(SimUseDaemonWatchdog.recoveryLimit) times in this run. The sim-use daemon for this device is probably hung: \
            check `jev-sim-use exec daemon status`, stop it with `jev-sim-use exec daemon stop --device \(deviceID)`, then \
            `jev-sim-use session resume`.
            """
        case let .targetNotRevealed(scroll, _):
            "The element to tap was not found after \(scroll.summary.lowercased()) to reveal it."
        }
    }
}

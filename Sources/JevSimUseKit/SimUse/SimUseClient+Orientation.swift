import Foundation

extension SimUseClient {
    /// The orientation of a reading whose orientation sim-use only assumed. On a turned simulator it assumed
    /// landscape-right while the screen was landscape-left, and every converted coordinate landed mirrored.
    ///
    /// A simulator's backboardd publishes the device orientation, which the Simulator's rotate commands set. It says
    /// which landscape side the device is on, but not whether the app turned with it (a portrait-only app does not),
    /// so it is asked only when the screen sim-use read is wider than tall. Anything else keeps sim-use's guess.
    func settledOrientation(of snapshot: UISnapshot) async -> String? {
        guard device.kind == Self.simulatorKind, let screen = snapshot.screen, screen.width > screen.height else {
            return snapshot.orientation
        }
        let arguments = ["simctl", "spawn", device.deviceId, "notifyutil", "-g", Self.deviceOrientationKey]
        let output = try? await invoker.runner.run(Self.xcrun, arguments: arguments, environment: [:])
        guard let output, output.exitCode == 0,
              let value = String(decoding: output.stdout, as: UTF8.self).split(separator: " ").last?
              .trimmingCharacters(in: .whitespacesAndNewlines)
        else { return snapshot.orientation }
        // UIDeviceOrientation: landscapeLeft (3) turns the interface to landscape-right, and landscapeRight (4) to
        // landscape-left.
        return switch value {
        case "3": ScreenSpace.landscapeRight
        case "4": ScreenSpace.landscapeLeft
        default: snapshot.orientation
        }
    }

    static let simulatorKind = "simulator"
    static let xcrun = URL(filePath: "/usr/bin/xcrun")
    static let deviceOrientationKey = "com.apple.backboardd.orientation"
}

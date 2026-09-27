import Foundation

/// Finds a booted simulator's own display through CoreSimulator, the private framework Xcode installs for every
/// simulator client (idb's framebuffer takes the same path: service context, device set, device, IO ports, the display
/// port of class 0). Every step is a checked `PrivateMessage`, so a framework that changed fails with an error.
struct CoreSimulatorLocator: Sendable {
    /// Where Xcode installs CoreSimulator; its display classes live in the `CoreSimDeviceIO` framework it loads.
    static let defaultFrameworkPath = "/Library/Developer/PrivateFrameworks/CoreSimulator.framework/CoreSimulator"

    /// The CoreSimulator binary to load.
    let frameworkPath: String
    /// The selected Xcode's `Contents/Developer`, which the service context is opened for.
    let developerDirectory: String

    init(frameworkPath: String = Self.defaultFrameworkPath, developerDirectory: String) {
        self.frameworkPath = frameworkPath
        self.developerDirectory = developerDirectory
    }

    /// The display descriptor of the booted simulator `id`: an object answering `framebufferSurface` and the frame
    /// callbacks.
    func mainDisplay(ofDevice id: String) throws(ScreenWatchError) -> NSObject {
        guard UUID(uuidString: id) != nil else { throw .deviceNotFound(id) }
        guard dlopen(frameworkPath, RTLD_NOW) != nil else { throw .frameworkMissing(path: frameworkPath) }
        guard let contextClass = NSClassFromString("SimServiceContext") else { throw .classMissing("SimServiceContext") }

        let context = try PrivateMessage.object(
            contextClass, "sharedServiceContextForDeveloperDir:error:", developerDirectory as NSString,
        )
        let deviceSet = try PrivateMessage.object(context, errorOut: "defaultDeviceSetWithError:")
        guard let devices = try PrivateMessage.object(deviceSet, "devicesByUDID") as? [AnyHashable: Any] else {
            throw .noResult("devicesByUDID")
        }
        let io = try PrivateMessage.object(Self.device(id, in: devices), "io")
        guard let ports = try PrivateMessage.object(io, "ioPorts") as? [NSObject] else { throw .noResult("ioPorts") }
        return try Self.mainDisplay(among: ports)
    }

    /// The device `id` among CoreSimulator's devices by UDID, when it is booted.
    static func device(_ id: String, in devices: [AnyHashable: Any]) throws(ScreenWatchError) -> NSObject {
        let uuid = UUID(uuidString: id)
        let match = devices.first { key, _ in
            (key.base as? UUID ?? (key.base as? NSUUID).map { $0 as UUID }) == uuid
        }
        guard let device = match?.value as? NSObject else { throw .deviceNotFound(id) }
        guard try PrivateMessage.object(device, "stateString") as? String == "Booted" else { throw .deviceNotBooted(id) }
        return device
    }

    /// The descriptor of the port whose display class is 0, the device's own screen; the others are external displays.
    static func mainDisplay(among ports: [NSObject]) throws(ScreenWatchError) -> NSObject {
        for port in ports {
            // A port that is not a display (audio, HID, Metal) answers none of these; it is skipped, not an error.
            guard let descriptor = try? PrivateMessage.object(port, "descriptor"),
                  let state = try? PrivateMessage.object(descriptor, "state"),
                  (try? PrivateMessage.unsigned(state, "displayClass")) == 0
            else { continue }
            return descriptor
        }
        throw .noMainDisplay
    }
}

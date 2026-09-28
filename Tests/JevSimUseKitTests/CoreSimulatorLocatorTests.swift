import Foundation
@testable import JevSimUseKit
import Testing

/// Ways finding the simulator's display through private frameworks can fail. Each must end in a `ScreenWatchError`
/// the loop falls back on, never a crash or a watcher on another device's display.
@Suite("Finding the simulator's main display fails safely")
struct CoreSimulatorLocatorTests {
    private static let udid = "B35B0000-0000-0000-0000-000000000001"

    @Test("reports a missing CoreSimulator framework")
    func frameworkMissing() {
        let locator = CoreSimulatorLocator(frameworkPath: "/nonexistent/CoreSimulator", developerDirectory: "/nonexistent")
        #expect(throws: ScreenWatchError.frameworkMissing(path: "/nonexistent/CoreSimulator")) {
            try locator.mainDisplay(ofDevice: Self.udid)
        }
    }

    @Test("refuses an id that is not a simulator's, before loading anything")
    func notASimulatorID() {
        let locator = CoreSimulatorLocator(frameworkPath: "/nonexistent/CoreSimulator", developerDirectory: "/nonexistent")
        #expect(throws: ScreenWatchError.deviceNotFound("emulator-5554")) {
            try locator.mainDisplay(ofDevice: "emulator-5554")
        }
    }

    @Test("finds only the pinned device, and only while it is booted")
    func pinnedDevice() throws {
        let devices: [AnyHashable: Any] = try [
            #require(UUID(uuidString: Self.udid)): FakeSimDevice(state: "Booted"),
            UUID(): FakeSimDevice(state: "Booted"),
        ]
        #expect(try CoreSimulatorLocator.device(Self.udid, in: devices) === devices[#require(UUID(uuidString: Self.udid))] as? NSObject)
        let other = UUID().uuidString
        #expect(throws: ScreenWatchError.deviceNotFound(other)) { try CoreSimulatorLocator.device(other, in: devices) }
        let shutDown: [AnyHashable: Any] = try [#require(UUID(uuidString: Self.udid)): FakeSimDevice(state: "Shutdown")]
        #expect(throws: ScreenWatchError.deviceNotBooted(Self.udid)) { try CoreSimulatorLocator.device(Self.udid, in: shutDown) }
    }

    /// A simulator lists several display ports (external and CarPlay ones among them); only display class 0 is the
    /// device's own screen.
    @Test("picks the display of class 0 among the ports, skipping ports that are not displays")
    func mainDisplay() throws {
        let main = FakeDisplay(displayClass: 0)
        let ports = [FakePort(descriptor: NSObject()), FakePort(descriptor: FakeDisplay(displayClass: 1)), FakePort(descriptor: main)]
        #expect(try CoreSimulatorLocator.mainDisplay(among: ports) === main)
        #expect(throws: ScreenWatchError.noMainDisplay) {
            try CoreSimulatorLocator.mainDisplay(among: [FakePort(descriptor: FakeDisplay(displayClass: 1))])
        }
    }
}

/// Every private message goes through a guard: a missing selector, another signature, or an Objective-C exception
/// becomes an error instead of undefined behaviour or a crash.
@Suite("Private messages are checked and guarded")
struct PrivateMessageTests {
    @Test("reports a selector the receiver does not answer")
    func selectorMissing() {
        #expect(throws: ScreenWatchError.selectorMissing("ioPorts")) { try PrivateMessage.object(NSObject(), "ioPorts") }
    }

    @Test("reports a selector whose signature changed instead of calling it")
    func signatureChanged() {
        #expect(throws: ScreenWatchError.unexpectedSignature("descriptor")) {
            try PrivateMessage.object(ChangedSignature(), "descriptor")
        }
    }

    @Test("turns an Objective-C exception into an error")
    func exceptionCaught() {
        #expect(throws: ScreenWatchError.raised(selector: "descriptor", reason: "gone")) {
            try PrivateMessage.object(Raising(), "descriptor")
        }
    }
}

private final class FakeSimDevice: NSObject {
    private let state: String

    init(state: String) {
        self.state = state
    }

    @objc func stateString() -> NSString {
        state as NSString
    }
}

private final class FakePort: NSObject {
    private let wrapped: NSObject

    init(descriptor: NSObject) {
        wrapped = descriptor
    }

    @objc func descriptor() -> NSObject {
        wrapped
    }
}

private final class FakeDisplayState: NSObject {
    private let value: UInt16

    init(displayClass: UInt16) {
        value = displayClass
    }

    @objc func displayClass() -> UInt16 {
        value
    }
}

private final class FakeDisplay: NSObject {
    private let wrapped: FakeDisplayState

    init(displayClass: UInt16) {
        wrapped = FakeDisplayState(displayClass: displayClass)
    }

    @objc func state() -> NSObject {
        wrapped
    }
}

private final class ChangedSignature: NSObject {
    @objc func descriptor() -> Int {
        0
    }
}

private final class Raising: NSObject {
    @objc func descriptor() -> NSObject {
        NSException(name: .genericException, reason: "gone").raise()
        return NSObject()
    }
}

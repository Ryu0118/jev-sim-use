@testable import JevSimUseKit
import Testing

struct SimUseDeviceActionTests {
    @Test("maps intent to sim-use's finger-direction preset names")
    func scrollNaming() {
        #expect(SimUseDeviceAction.revealContentBelow.arguments(platform: "ios") == ["gesture", "scroll-up", "--duration", "1.5"])
        #expect(SimUseDeviceAction.revealContentAbove.arguments(platform: "ios") == ["gesture", "scroll-down", "--duration", "1.5"])
    }

    @Test("goes back with the edge swipe on iOS and the back button on Android")
    func back() {
        #expect(SimUseDeviceAction.goBack.arguments(platform: "ios") == ["gesture", "swipe-from-left-edge"])
        #expect(SimUseDeviceAction.goBack.arguments(platform: "android") == ["button", "back"])
    }

    @Test("maps sideways scrolls, edge swipes, and buttons to sim-use's names")
    func otherActions() {
        #expect(SimUseDeviceAction.revealContentRight.arguments(platform: "ios") == ["gesture", "scroll-left", "--duration", "0.3"])
        #expect(SimUseDeviceAction.swipeFromRightEdge.arguments(platform: "ios") == ["gesture", "swipe-from-right-edge"])
        #expect(SimUseDeviceAction.press(.sideButton).arguments(platform: "ios") == ["button", "side-button"])
    }

    @Test("presses Return with the iOS HID key and with a typed newline on Android, where there is no key verb")
    func pressReturn() {
        #expect(SimUseDeviceAction.pressReturn.arguments(platform: "ios") == ["ios", "key", "40"])
        #expect(SimUseDeviceAction.pressReturn.arguments(platform: "android") == ["type", "\n"])
        #expect(SimUseDeviceAction.available(on: "ios").contains(.pressReturn))
    }

    @Test("offers only the buttons the platform has")
    func buttonsPerPlatform() {
        #expect(HardwareButton.available(on: "android") == [.home, .lock, .recents])
        #expect(!HardwareButton.available(on: "ios").contains(.recents))
    }

    @Test("offers Escape only on iOS, gated like an irreversible tap since it closed a filled form without asking")
    func escape() {
        #expect(SimUseDeviceAction.pressEscape.arguments(platform: "ios") == ["ios", "key", "41"])
        #expect(SimUseDeviceAction.available(on: "ios").contains(.pressEscape))
        #expect(!SimUseDeviceAction.available(on: "android").contains(.pressEscape))
        #expect(SimUseDeviceAction.pressEscape.risk == .irreversible)
    }

    @Test("does not offer Siri, whose press left the screen unreadable, and describes it as the press it sends")
    func siri() {
        #expect(!HardwareButton.available(on: "ios").contains(.siri))
        #expect(SimUseDeviceAction.press(.siri).arguments(platform: "ios") == ["button", "siri"])
        #expect(SimUseDeviceAction.press(.siri).optionDescription.hasPrefix("Press"))
    }
}

@testable import JevSimUseKit
import Testing

struct SimUseDeviceActionTests {
    @Test("maps intent to sim-use's finger-direction preset names")
    func scrollNaming() {
        #expect(SimUseDeviceAction.revealContentBelow.arguments(platform: "ios") == ["gesture", "scroll-up"])
        #expect(SimUseDeviceAction.revealContentAbove.arguments(platform: "ios") == ["gesture", "scroll-down"])
    }

    @Test("goes back with the edge swipe on iOS and the back button on Android")
    func back() {
        #expect(SimUseDeviceAction.goBack.arguments(platform: "ios") == ["gesture", "swipe-from-left-edge"])
        #expect(SimUseDeviceAction.goBack.arguments(platform: "android") == ["button", "back"])
    }

    @Test("maps sideways scrolls, edge swipes, and buttons to sim-use's names")
    func otherActions() {
        #expect(SimUseDeviceAction.revealContentRight.arguments(platform: "ios") == ["gesture", "scroll-left"])
        #expect(SimUseDeviceAction.swipeFromTopEdge.arguments(platform: "ios") == ["gesture", "swipe-from-top-edge"])
        #expect(SimUseDeviceAction.press(.sideButton).arguments(platform: "ios") == ["button", "side-button"])
    }

    @Test("offers only the buttons the platform has")
    func buttonsPerPlatform() {
        #expect(HardwareButton.available(on: "android") == [.home, .lock, .recents])
        #expect(!HardwareButton.available(on: "ios").contains(.recents))
    }
}

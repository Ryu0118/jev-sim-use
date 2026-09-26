@testable import JevSimUseKit
import Testing

/// sim-use names its presets by finger direction and differs by platform. Scrolling down and pressing Return on iOS
/// run end to end in scripts/e2e.sh; this is the whole mapping, one row per action and platform.
@Suite("Each screen-level action maps to sim-use's own command on each platform")
struct SimUseDeviceActionTests {
    @Test("sends the sim-use arguments for the intent", arguments: [
        ("scrolling to reveal content below swipes up, slowly enough to stop with the finger",
         SimUseDeviceAction.revealContentBelow, "ios", ["gesture", "scroll-up", "--duration", "1.5"]),
        ("revealing content above swipes down", .revealContentAbove, "ios", ["gesture", "scroll-down", "--duration", "1.5"]),
        ("revealing content to the right turns one page", .revealContentRight, "ios", ["gesture", "scroll-left", "--duration", "0.3"]),
        ("revealing content to the left turns one page back", .revealContentLeft, "ios", ["gesture", "scroll-right", "--duration", "0.3"]),
        ("going back on iOS is the left-edge swipe", .goBack, "ios", ["gesture", "swipe-from-left-edge"]),
        ("going back on Android is its back button", .goBack, "android", ["button", "back"]),
        ("the right-edge swipe", .swipeFromRightEdge, "ios", ["gesture", "swipe-from-right-edge"]),
        ("a hardware button by its sim-use name", .press(.sideButton), "ios", ["button", "side-button"]),
        ("Return on iOS is the HID key", .pressReturn, "ios", ["ios", "key", "40"]),
        ("Return on Android, which has no key verb, is a typed newline", .pressReturn, "android", ["type", "\n"]),
        ("Escape on iOS is HID key 41, which `ios key --help` does not list", .pressEscape, "ios", ["ios", "key", "41"]),
        ("Siri is the plain press it is described as", .press(.siri), "ios", ["button", "siri"]),
        ("pulling to refresh is one fast, long swipe down: the slow scroll preset and a row's swipe fell short of the threshold",
         .pullToRefresh(x: 201, from: 262, to: 743), "ios", ["swipe", "--from", "201.0,262.0", "--to", "201.0,743.0", "--duration", "0.3"]),
    ] as [(String, SimUseDeviceAction, String, [String])])
    func arguments(_: String, action: SimUseDeviceAction, platform: String, expected: [String]) {
        #expect(action.arguments(platform: platform) == expected)
    }

    @Test("gates Escape like an irreversible tap, since it closed a form holding typed text without asking")
    func escapeRisk() {
        #expect(SimUseDeviceAction.pressEscape.risk == .irreversible)
    }
}

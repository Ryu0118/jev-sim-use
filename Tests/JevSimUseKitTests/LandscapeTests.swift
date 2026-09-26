import Foundation
@testable import JevSimUseKit
import Testing

/// In landscape, describe-ui's points are the screen as shown while sim-use's coordinate commands take device-native
/// portrait points. The mappings were found on a simulator by touching a switch in each orientation.
struct LandscapeTests {
    private static let wide = ElementFrame(x: 0, y: 0, width: 874, height: 402)

    @Test("maps a shown point to the device-native one only where the screen is turned", arguments: [
        ("portrait passes through", ScreenSpace(platform: "ios", orientation: "portrait", screen: ElementFrame(x: 0, y: 0, width: 402, height: 874)),
         750.0, 286.0, 750.0, 286.0),
        ("landscape-right", ScreenSpace(platform: "ios", orientation: "landscape-right", screen: wide), 750, 286, 116, 750),
        ("landscape-left", ScreenSpace(platform: "ios", orientation: "landscape-left", screen: wide), 750, 286, 286, 124),
        ("Android reports display coordinates", ScreenSpace(platform: "android", orientation: "landscape-right", screen: wide), 750, 286, 750, 286),
        ("no screen size to turn by", ScreenSpace(platform: "ios", orientation: "landscape-right"), 750, 286, 750, 286),
        ("upside-down is unverified and passes through", ScreenSpace(platform: "ios", orientation: "portrait-upside-down", screen: wide),
         750, 286, 750, 286),
    ] as [(String, ScreenSpace, Double, Double, Double, Double)])
    func mapping(_: String, space: ScreenSpace, x: Double, y: Double, nativeX: Double, nativeY: Double) {
        let point = space.native(x: x, y: y)
        #expect(point.x == nativeX && point.y == nativeY)
    }

    @Test("taps a switch in landscape on its trailing edge where the device takes it")
    func switchTap() async throws {
        let runner = FakeCommandRunner(["tap": .json(#"{"ok":true,"data":{}}"#)])
        let toggle = Fixtures.entry(14, "All-day", role: "CheckBox", frame: ElementFrame(x: 113, y: 272, width: 663, height: 28))
        let client = SimUseClient(
            device: Fixtures.device(Fixtures.simulator), invoker: SimUseInvoker(executable: URL(filePath: "/sim-use"), runner: runner),
        )
        _ = try await client.tap(alias: 14, on: Self.landscape([toggle]))
        #expect(runner.recordedCalls.first?.prefix(5) == ["tap", "-x", "116.0", "-y", "750.0"])
    }

    @Test("turns an element swipe and a pinch's pivot with the screen")
    func elementGestures() {
        let row = ElementFrame(x: 100, y: 100, width: 600, height: 50)
        let space = Self.landscape([], "landscape-left").space
        #expect(ElementGesture.swipeLeft.arguments(alias: 1, frame: row, in: space)
            == ["swipe", "--from", "125.0,234.0", "--to", "125.0,474.0"])
        #expect(ElementGesture.pinchOut.arguments(alias: 1, frame: row, in: space)
            == ["gesture", "pinch-out", "--center-x", "125.0", "--center-y", "474.0"])
    }

    @Test("turns a pull to refresh and a two-finger row selection with the screen")
    func screenGestures() {
        let space = Self.landscape([]).space
        #expect(SimUseDeviceAction.pullToRefresh(x: 437, from: 121, to: 342).arguments(in: space)
            == ["swipe", "--from", "281.0,437.0", "--to", "60.0,437.0", "--duration", "0.3"])
        let first = ElementFrame(x: 100, y: 100, width: 600, height: 40), last = ElementFrame(x: 100, y: 300, width: 600, height: 40)
        #expect(SimUseDeviceAction.selectRows(from: first, to: last).arguments(in: space) == [
            "multi-touch", "--x1", "282.0", "--y1", "380.0", "--x2", "282.0", "--y2", "420.0",
            "--x1-end", "82.0", "--y1-end", "380.0", "--x2-end", "82.0", "--y2-end", "420.0", "--duration", "0.8",
        ])
    }

    private static func landscape(_ entries: [UIEntry], _ orientation: String = "landscape-right") -> UISnapshot {
        var snapshot = Fixtures.snapshot(entries: entries)
        snapshot.screen = wide
        snapshot.orientation = orientation
        return snapshot
    }
}

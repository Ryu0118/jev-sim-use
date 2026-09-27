@testable import JevSimUseKit
import Testing

/// Coordinates built from an element's frame can fall outside the screen: a row an earlier swipe had moved left gave
/// `swipe --from 156.8,189.0 --to -4.0,189.0`, and sim-use read the negative point as an option. Points are kept a
/// little inside the screen, in the space the frames are in, and joined to their flag so none reads as an option.
struct CoordinateBoundsTests {
    private static let portrait = ScreenSpace(platform: "ios", orientation: "portrait", screen: ElementFrame(x: 0, y: 0, width: 402, height: 874))

    @Test("keeps a swipe on a row moved past the left edge on the screen")
    func swipeOffLeftEdge() {
        let moved = ElementFrame(x: -205, y: 168, width: 402, height: 42)
        #expect(ElementGesture.swipeLeft.arguments(alias: 1, frame: moved, in: Self.portrait)
            == ["swipe", "--from=156.8,189.0", "--to=8.0,189.0"])
    }

    @Test("keeps a two-finger pivot on the screen when the element runs past its edge")
    func pivotOffRightEdge() {
        let wide = ElementFrame(x: 300, y: 400, width: 300, height: 100)
        #expect(ElementGesture.pinchOut.arguments(alias: 1, frame: wide, in: Self.portrait)
            == ["gesture", "pinch-out", "--center-x=394.0", "--center-y=450.0"])
    }

    @Test("keeps a point on the screen as shown before turning it to the device's space")
    func clampsBeforeTurning() {
        let space = ScreenSpace(platform: "ios", orientation: "landscape-right", screen: ElementFrame(x: 0, y: 0, width: 874, height: 402))
        let point = space.native(x: -4, y: 189)
        #expect(point.x == 213 && point.y == 8)
    }

    @Test("joins a point to its flag even when no screen size bounds it")
    func joinedWithoutScreen() {
        let moved = ElementFrame(x: -205, y: 168, width: 402, height: 42)
        #expect(ElementGesture.swipeLeft.arguments(alias: 1, frame: moved, in: ScreenSpace(platform: "ios"))
            == ["swipe", "--from=156.8,189.0", "--to=-4.0,189.0"])
    }
}

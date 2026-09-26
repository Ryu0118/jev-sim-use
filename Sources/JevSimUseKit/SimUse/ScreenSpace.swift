/// How the points describe-ui reports map to the ones sim-use's coordinate commands take.
///
/// On iOS, describe-ui reports frames as the screen shows them, but `tap -x/-y`, `swipe`, `multi-touch`, and the
/// two-finger presets' pivot take device-native portrait points. In landscape a trailing-edge tap on a switch landed
/// off the screen and an element swipe moved sideways, so every coordinate is converted here. Android reports display
/// coordinates, which those commands take as they are.
package struct ScreenSpace: Sendable, Hashable {
    /// `ios` or `android`.
    package let platform: String
    /// sim-use's orientation, such as `portrait` or `landscape-right`; `nil` when not reported.
    let orientation: String?
    /// The screen as shown, in describe-ui's points.
    let screen: ElementFrame?

    package init(platform: String, orientation: String? = nil, screen: ElementFrame? = nil) {
        self.platform = platform
        self.orientation = orientation
        self.screen = screen
    }

    /// The device-native point for `x`, `y` as describe-ui shows it. Found on a simulator by touching a switch in both
    /// landscape orientations. Portrait, an unknown orientation, and upside-down (unverified) pass through unchanged.
    func native(x: Double, y: Double) -> (x: Double, y: Double) {
        guard platform == SimUseContract.Platform.ios, let screen else { return (x, y) }
        return switch orientation {
        case Self.landscapeRight: (screen.height - y, x)
        case Self.landscapeLeft: (y, screen.width - x)
        default: (x, y)
        }
    }

    static let landscapeRight = "landscape-right"
    static let landscapeLeft = "landscape-left"
}

package extension UISnapshot {
    /// The coordinate space of this reading's frames.
    var space: ScreenSpace {
        ScreenSpace(platform: platform, orientation: orientation, screen: screen)
    }
}

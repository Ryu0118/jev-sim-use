/// A gesture on one element other than a plain tap.
///
/// sim-use has no double tap: two `tap` calls land about 0.4 s apart, outside iOS's double-tap window, so none is
/// offered.
package enum ElementGesture: String, Sendable, Hashable, CaseIterable {
    case longPress = "long_press"
    case swipeLeft = "swipe_left"
    case swipeRight = "swipe_right"
    case swipeUp = "swipe_up"
    case swipeDown = "swipe_down"
    case pinchOut = "pinch_out"
    case pinchIn = "pinch_in"
    case rotateClockwise = "rotate_clockwise"
    case rotateCounterclockwise = "rotate_counterclockwise"

    /// The sim-use arguments for this gesture on the element `@alias` with `frame`, as the screen `space` describes
    /// shows it.
    func arguments(alias: Int, frame: ElementFrame, in space: ScreenSpace) -> [String] {
        typealias Gesture = SimUseContract.Gesture
        let center = frame.center
        // Horizontal swipes travel 40% of the width: enough to reveal a row's actions, short of the full swipe that
        // deletes a Reminders row without asking. Vertical swipes run across 80% of the element.
        let insetX = frame.width * 0.1, insetY = frame.height * 0.1
        func swipe(from: (Double, Double), to: (Double, Double)) -> [String] {
            SimUseContract.Swipe.arguments(from: space.native(x: from.0, y: from.1), to: space.native(x: to.0, y: to.1))
        }
        func twoFinger(_ preset: String) -> [String] {
            let pivot = space.native(x: center.x, y: center.y)
            return [SimUseContract.Command.gesture, preset, Gesture.centerX, "\(pivot.x)", Gesture.centerY, "\(pivot.y)"]
        }
        return switch self {
        case .longPress: [SimUseContract.Command.longPress, "@\(alias)"]
        case .swipeLeft: swipe(from: (frame.x + frame.width - insetX, center.y), to: (center.x, center.y))
        case .swipeRight: swipe(from: (frame.x + insetX, center.y), to: (center.x, center.y))
        case .swipeUp: swipe(from: (center.x, frame.y + frame.height - insetY), to: (center.x, frame.y + insetY))
        case .swipeDown: swipe(from: (center.x, frame.y + insetY), to: (center.x, frame.y + frame.height - insetY))
        case .pinchOut: twoFinger(Gesture.pinchOut)
        case .pinchIn: twoFinger(Gesture.pinchIn)
        case .rotateClockwise: twoFinger(Gesture.rotateClockwise)
        case .rotateCounterclockwise: twoFinger(Gesture.rotateCounterclockwise)
        }
    }
}

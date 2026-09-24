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

    /// The sim-use arguments for this gesture on the element `@alias` with `frame`. Frames and the pivot and swipe
    /// coordinates share describe-ui's space (points on iOS).
    func arguments(alias: Int, frame: ElementFrame) -> [String] {
        typealias Gesture = SimUseContract.Gesture
        let center = frame.center
        // Horizontal swipes travel 40% of the width: enough to reveal a row's actions, short of the full swipe that
        // deletes a Reminders row without asking. Vertical swipes run across 80% of the element.
        let insetX = frame.width * 0.1, insetY = frame.height * 0.1
        func swipe(from: (Double, Double), to: (Double, Double)) -> [String] {
            [SimUseContract.Command.swipe, SimUseContract.Swipe.from, "\(from.0),\(from.1)", SimUseContract.Swipe.to, "\(to.0),\(to.1)"]
        }
        func twoFinger(_ preset: String) -> [String] {
            [SimUseContract.Command.gesture, preset, Gesture.centerX, "\(center.x)", Gesture.centerY, "\(center.y)"]
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

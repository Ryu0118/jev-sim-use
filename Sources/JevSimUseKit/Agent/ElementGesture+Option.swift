extension ElementGesture {
    /// The rubric Jev reads in `operation`, which says what the gesture is for.
    var optionDescription: String {
        switch self {
        case .longPress: "Press and hold an element, to open its context menu or start rearranging"
        case .swipeLeft: "Swipe left across one element, to reveal a row's actions such as Delete, or move a carousel inside it; not for moving the whole screen to the next page or photo, which scrolling sideways does"
        case .swipeRight: "Swipe right across one element, to reveal a row's leading actions or move a carousel inside it back; not for moving the whole screen back a page or photo, which scrolling sideways does"
        case .swipeUp: "Swipe up within one element, to move only that element's content; not for scrolling the screen"
        case .swipeDown: "Swipe down within one element, to move only that element's content; not for scrolling the screen"
        case .pinchOut: "Spread two fingers on an element, to zoom in"
        case .pinchIn: "Pinch two fingers on an element, to zoom out"
        case .rotateClockwise: "Rotate two fingers clockwise on an element, to turn a map or picture and change the heading its compass shows"
        case .rotateCounterclockwise: "Rotate two fingers counterclockwise on an element, to turn a map or picture and change the heading its compass shows"
        }
    }

    /// The verb used in progress lines and `history`.
    var verb: String {
        switch self {
        case .longPress: "Long-press"
        case .swipeLeft: "Swipe left on"
        case .swipeRight: "Swipe right on"
        case .swipeUp: "Swipe up on"
        case .swipeDown: "Swipe down on"
        case .pinchOut: "Zoom in on"
        case .pinchIn: "Zoom out on"
        case .rotateClockwise: "Rotate clockwise"
        case .rotateCounterclockwise: "Rotate counterclockwise"
        }
    }

    /// How costly the gesture is when wrong. Horizontal swipes stop short of a full swipe, so they reveal a row's
    /// actions rather than run them.
    var risk: ActionRisk {
        switch self {
        // Zooming and rotating only change the view, like scrolling.
        case .pinchOut, .pinchIn, .rotateClockwise, .rotateCounterclockwise: .harmless
        case .longPress, .swipeLeft, .swipeRight, .swipeUp, .swipeDown: .reversible
        }
    }
}

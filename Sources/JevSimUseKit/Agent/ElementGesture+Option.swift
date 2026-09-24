extension ElementGesture {
    /// The rubric Jev reads in `element_gesture`, which says what the gesture is for.
    var optionDescription: String {
        switch self {
        case .longPress: "Press and hold it, to open its context menu or start rearranging"
        case .swipeLeft: "Swipe left across it, to reveal row actions or move a carousel forward"
        case .swipeRight: "Swipe right across it, to reveal leading row actions or move a carousel back"
        case .swipeUp: "Swipe up within it, to move its own content up"
        case .swipeDown: "Swipe down within it, to move its own content down or refresh it"
        case .pinchOut: "Spread two fingers on it, to zoom in"
        case .pinchIn: "Pinch two fingers on it, to zoom out"
        case .rotateClockwise: "Rotate two fingers clockwise on it"
        case .rotateCounterclockwise: "Rotate two fingers counterclockwise on it"
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

    /// How costly the gesture is when wrong.
    var risk: ActionRisk {
        switch self {
        // A long horizontal swipe on a list row can delete it.
        case .swipeLeft, .swipeRight: .irreversible
        case .longPress, .swipeUp, .swipeDown, .pinchOut, .pinchIn, .rotateClockwise, .rotateCounterclockwise: .reversible
        }
    }
}

extension ElementGesture {
    /// The rubric Jev reads in `operation`, which says what the gesture is for.
    var optionDescription: String {
        switch self {
        case .longPress: "Press and hold an element, to open its context menu or start rearranging"
        case .swipeLeft: "Swipe left across an element, to reveal row actions or move a carousel forward"
        case .swipeRight: "Swipe right across an element, to reveal leading row actions or move a carousel back"
        case .swipeUp: "Swipe up within an element, to move its own content up"
        case .swipeDown: "Swipe down within an element, to move its own content down or refresh it"
        case .pinchOut: "Spread two fingers on an element, to zoom in"
        case .pinchIn: "Pinch two fingers on an element, to zoom out"
        case .rotateClockwise: "Rotate two fingers clockwise on an element"
        case .rotateCounterclockwise: "Rotate two fingers counterclockwise on an element"
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

    /// How costly the gesture is when wrong on an element with `role`.
    func risk(on role: String) -> ActionRisk {
        switch self {
        // A long horizontal swipe on a list row can delete it; on a slider, image, or carousel it only moves.
        case .swipeLeft, .swipeRight: ActionCatalog.rowRoles.contains { role.contains($0) } ? .irreversible : .reversible
        case .longPress, .swipeUp, .swipeDown, .pinchOut, .pinchIn, .rotateClockwise, .rotateCounterclockwise: .reversible
        }
    }
}

/// A device-level action that does not target a specific element.
package enum SimUseDeviceAction: Sendable, Hashable {
    /// Scroll so that content further down comes into view.
    case revealContentBelow
    /// Scroll so that content further up comes into view.
    case revealContentAbove
    /// Scroll sideways so that content further right comes into view.
    case revealContentRight
    /// Scroll sideways so that content further left comes into view.
    case revealContentLeft
    /// Navigate back: the edge swipe on iOS, the back button on Android.
    case goBack
    /// Swipe down from the top edge.
    case swipeFromTopEdge
    /// Swipe up from the bottom edge.
    case swipeFromBottomEdge
    /// Swipe in from the right edge.
    case swipeFromRightEdge
    /// Press a hardware button.
    case press(HardwareButton)

    /// Every action sim-use supports on `platform`.
    static func available(on platform: String) -> [SimUseDeviceAction] {
        [
            .revealContentBelow, .revealContentAbove, .revealContentRight, .revealContentLeft, .goBack,
            .swipeFromTopEdge, .swipeFromBottomEdge, .swipeFromRightEdge,
        ] + HardwareButton.available(on: platform).map(SimUseDeviceAction.press)
    }

    /// The sim-use arguments for this action on `platform`.
    func arguments(platform: String) -> [String] {
        typealias Gesture = SimUseContract.Gesture
        let gesture = SimUseContract.Command.gesture
        return switch self {
        // sim-use names presets by finger direction: `scroll-up` pages down, `scroll-left` shows what is right.
        case .revealContentBelow: [gesture, Gesture.scrollUp]
        case .revealContentAbove: [gesture, Gesture.scrollDown]
        case .revealContentRight: [gesture, Gesture.scrollLeft]
        case .revealContentLeft: [gesture, Gesture.scrollRight]
        case .goBack:
            platform == "android"
                ? [SimUseContract.Command.button, SimUseContract.Button.back]
                : [gesture, Gesture.swipeFromLeftEdge]
        case .swipeFromTopEdge: [gesture, Gesture.swipeFromTopEdge]
        case .swipeFromBottomEdge: [gesture, Gesture.swipeFromBottomEdge]
        case .swipeFromRightEdge: [gesture, Gesture.swipeFromRightEdge]
        case let .press(button): [SimUseContract.Command.button, button.argument]
        }
    }
}

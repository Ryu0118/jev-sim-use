/// A device-level action that does not target a specific element.
package enum SimUseDeviceAction: Sendable, Hashable {
    /// Scroll so that content further down comes into view.
    case revealContentBelow
    /// Scroll so that content further up comes into view.
    case revealContentAbove
    /// Navigate back: the edge swipe on iOS, the back button on Android.
    case goBack

    /// The sim-use arguments for this action on `platform`.
    func arguments(platform: String) -> [String] {
        switch self {
        // sim-use names presets by finger direction: `scroll-up` pages down.
        case .revealContentBelow: [SimUseContract.Command.gesture, SimUseContract.Gesture.scrollUp]
        case .revealContentAbove: [SimUseContract.Command.gesture, SimUseContract.Gesture.scrollDown]
        case .goBack:
            platform == "android"
                ? [SimUseContract.Command.button, SimUseContract.Button.back]
                : [SimUseContract.Command.gesture, SimUseContract.Gesture.swipeFromLeftEdge]
        }
    }
}

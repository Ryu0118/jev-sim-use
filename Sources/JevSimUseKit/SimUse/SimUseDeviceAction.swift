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
    /// Swipe in from the right edge. There is no top- or bottom-edge action: on iOS 26 those presets did nothing, and a
    /// real swipe from the top opens Control Center, which `sim-use ui` then cannot read.
    case swipeFromRightEdge
    /// Press a hardware button.
    case press(HardwareButton)
    /// Press Return on the keyboard: submits a search field or a form that acts only on Return.
    case pressReturn

    /// Every action sim-use supports on `platform`.
    static func available(on platform: String) -> [SimUseDeviceAction] {
        [
            .revealContentBelow, .revealContentAbove, .revealContentRight, .revealContentLeft, .goBack,
            .swipeFromRightEdge, .pressReturn,
        ] + HardwareButton.available(on: platform).map(SimUseDeviceAction.press)
    }

    /// The sim-use arguments for this action on `platform`.
    func arguments(platform: String) -> [String] {
        typealias Gesture = SimUseContract.Gesture
        let gesture = SimUseContract.Command.gesture
        return switch self {
        // sim-use names presets by finger direction: `scroll-up` pages down, `scroll-left` shows what is right.
        // A 0.5 s vertical flick kept a list coasting for over three seconds, and a tap in that time only stopped
        // it; drawn over 1.5 s the list stops with the finger.
        case .revealContentBelow: [gesture, Gesture.scrollUp, Gesture.duration, Gesture.verticalSeconds]
        case .revealContentAbove: [gesture, Gesture.scrollDown, Gesture.duration, Gesture.verticalSeconds]
        // At the default 0.5 s a sideways scroll is too slow to turn a page; 0.3 s turns exactly one.
        case .revealContentRight: [gesture, Gesture.scrollLeft, Gesture.duration, Gesture.sidewaysSeconds]
        case .revealContentLeft: [gesture, Gesture.scrollRight, Gesture.duration, Gesture.sidewaysSeconds]
        case .goBack:
            platform == SimUseContract.Platform.android
                ? [SimUseContract.Command.button, SimUseContract.Button.back]
                : [gesture, Gesture.swipeFromLeftEdge]
        case .swipeFromRightEdge: [gesture, Gesture.swipeFromRightEdge]
        case let .press(button): [SimUseContract.Command.button, button.rawValue]
        case .pressReturn:
            platform == SimUseContract.Platform.android
                ? [SimUseContract.Command.type, SimUseContract.Key.newline]
                : SimUseContract.Command.iosKey + [SimUseContract.Key.returnKeycode]
        }
    }
}

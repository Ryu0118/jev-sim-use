extension SimUseDeviceAction {
    /// The option name Jev sees, named by intent rather than by sim-use's finger-direction preset.
    var optionName: String {
        switch self {
        case .revealContentBelow: "scroll_to_reveal_below"
        case .revealContentAbove: "scroll_to_reveal_above"
        case .revealContentRight: "scroll_to_reveal_right"
        case .revealContentLeft: "scroll_to_reveal_left"
        case .goBack: "go_back"
        case .swipeFromTopEdge: "swipe_down_from_top_edge"
        case .swipeFromBottomEdge: "swipe_up_from_bottom_edge"
        case .swipeFromRightEdge: "swipe_in_from_right_edge"
        case .press(.sideButton): "press_side_button"
        case let .press(button): "press_\(button.rawValue.replacing("-", with: "_"))_button"
        }
    }

    /// The rubric Jev reads, which says what the action is for.
    var optionDescription: String {
        switch self {
        case .revealContentBelow: "Scroll down to show the items after the last one in `screen.elements`"
        case .revealContentAbove: "Scroll up to show the items before the first one in `screen.elements`"
        case .revealContentRight: "Scroll sideways to show the items to the right of those in `screen.elements`"
        case .revealContentLeft: "Scroll sideways to show the items to the left of those in `screen.elements`"
        case .goBack: "Go back to the previous screen, when `screen` is unrelated to `goal` or a dead end"
        case .swipeFromTopEdge: "Swipe down from the top edge of the screen, which opens notifications"
        case .swipeFromBottomEdge: "Swipe up from the bottom edge of the screen, which leaves the app for the Home Screen"
        case .swipeFromRightEdge: "Swipe in from the right edge of the screen"
        case .press(.home): "Press the Home button, which leaves the app for the Home Screen"
        case .press(.lock): "Press the lock button, which locks the device"
        case .press(.recents): "Press the recent apps button, which lists open apps"
        case .press(.applePay): "Double-press the side button for Apple Pay"
        case .press(.sideButton): "Press the side button"
        case .press(.siri): "Hold the button that starts Siri"
        }
    }

    /// How much going wrong costs, which sets the support `ActionPolicy` asks for.
    var risk: ActionRisk {
        switch self {
        case .revealContentBelow, .revealContentAbove, .revealContentRight, .revealContentLeft, .goBack: .harmless
        case .swipeFromTopEdge, .swipeFromRightEdge: .reversible
        // Leaving the app cannot be undone: sim-use has no launch verb.
        case .swipeFromBottomEdge, .press: .irreversible
        }
    }
}

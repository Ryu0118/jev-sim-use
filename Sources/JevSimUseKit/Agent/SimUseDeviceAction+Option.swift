extension SimUseDeviceAction {
    /// The option name Jev sees, named by intent rather than by sim-use's finger-direction preset.
    var optionName: String {
        switch self {
        case .revealContentBelow: "scroll_to_reveal_below"
        case .revealContentAbove: "scroll_to_reveal_above"
        case .revealContentRight: "scroll_to_reveal_right"
        case .revealContentLeft: "scroll_to_reveal_left"
        case .goBack: "go_back"
        case .swipeFromRightEdge: "swipe_in_from_right_edge"
        case let .press(button): "press_\(button.rawValue.replacing("-", with: "_"))"
        }
    }

    /// The rubric Jev reads, which says what the action is for.
    var optionDescription: String {
        switch self {
        case .revealContentBelow:
            "Scroll down: the item `goal` or `notes` names is not in `screen.elements` and may be further down this list"
        case .revealContentAbove:
            "Scroll up: the item `goal` or `notes` names is not in `screen.elements` and may be further up this list"
        case .revealContentRight:
            "Scroll sideways to the right: show the next page, photo, or items to the right of `screen.elements`"
        case .revealContentLeft:
            "Scroll sideways to the left: show the previous page, photo, or items to the left of `screen.elements`"
        case .goBack: "Go back to the previous screen, when `screen` is unrelated to `goal` or a dead end"
        case .swipeFromRightEdge: "Swipe in from the right edge of the screen"
        case .press(.home): "Press the Home button, which leaves the app for the Home Screen"
        case .press(.lock): "Press the lock button, which locks the device"
        case .press(.recents): "Press the recent apps button, which lists open apps"
        case .press(.applePay): "Double-press the side button for Apple Pay"
        case .press(.sideButton): "Press the side button"
        case .press(.siri): "Hold the button that starts Siri"
        }
    }

    /// What the action does, as a fact, for progress lines and `history`.
    var summary: String {
        switch self {
        case .revealContentBelow: "Scroll down"
        case .revealContentAbove: "Scroll up"
        case .revealContentRight: "Scroll sideways to the right"
        case .revealContentLeft: "Scroll sideways to the left"
        case .goBack: "Go back"
        case .swipeFromRightEdge: "Swipe in from the right edge"
        case .press(.home): "Press the Home button"
        case .press(.lock): "Press the lock button"
        case .press(.recents): "Press the recent apps button"
        case .press(.applePay): "Double-press the side button for Apple Pay"
        case .press(.sideButton): "Press the side button"
        case .press(.siri): "Hold the button that starts Siri"
        }
    }

    /// How much going wrong costs, which sets the support `ActionPolicy` asks for.
    var risk: ActionRisk {
        switch self {
        case .revealContentBelow, .revealContentAbove, .revealContentRight, .revealContentLeft, .goBack: .harmless
        case .swipeFromRightEdge: .reversible
        // Leaving the app cannot be undone: sim-use has no launch verb.
        case .press: .irreversible
        }
    }
}

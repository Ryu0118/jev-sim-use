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
        case .pressReturn: "press_return"
        case .pressEscape: "press_escape"
        case .selectRows: "select_rows_with_two_fingers"
        }
    }

    /// The rubric Jev reads, which says what the action is for.
    var optionDescription: String {
        switch self {
        case .revealContentBelow:
            "Scroll down: what `goal` names is not in `screen.elements` and no visible element is named in `goal`, and this list may continue below"
        case .revealContentAbove:
            "Scroll up: what `goal` names is not in `screen.elements` and no visible element is named in `goal`, and this list may continue above"
        case .revealContentRight:
            "Scroll sideways to the right: show the next page, photo, or items to the right of `screen.elements`"
        case .revealContentLeft:
            "Scroll sideways to the left: show the previous page, photo, or items to the left of `screen.elements`"
        case .goBack:
            "Go back to the previous screen, the one `screen.back` names; also when `screen.title` is a section `goal` "
                + "does not lead through"
        case .swipeFromRightEdge: "Swipe in from the right edge of the screen"
        case .press(.home):
            "Press the device's Home button, which leaves the app for the Home Screen; not for a home tab or screen "
                + "inside the app"
        case .press(.lock): "Press the lock button, which locks the device"
        case .press(.recents): "Press the recent apps button, which lists open apps"
        case .press(.applePay): "Double-press the side button for Apple Pay"
        case .press(.sideButton): "Press the side button"
        case .press(.siri): "Press the button that starts Siri"
        case .pressReturn:
            "Press Return on the keyboard: submit the text just typed, for a search field or form that shows its "
                + "result only after Return"
        case .pressEscape:
            "Press Escape on the keyboard: close the open menu, sheet, or dialog without choosing anything; a form it "
                + "closes loses what was typed"
        case .selectRows:
            "Drag two fingers down the list shown, from its first row to its last, to select all those rows at once "
                + "(multiple selection); in selection mode a tap then adds or removes one row"
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
        case .press(.siri): "Press the button that starts Siri"
        case .pressReturn: "Press Return"
        case .pressEscape: "Press Escape"
        case .selectRows: "Select the list's rows with two fingers"
        }
    }

    /// How much going wrong costs, which sets the support `ActionPolicy` asks for.
    var risk: ActionRisk {
        switch self {
        case .revealContentBelow, .revealContentAbove, .revealContentRight, .revealContentLeft, .goBack: .harmless
        // Return submits what was typed; jev-use gates it at 0.5, close to a tap.
        case .swipeFromRightEdge, .pressReturn: .reversible
        // Escape closed a form holding typed text without asking, and Jev cannot judge that as it does a tap.
        case .pressEscape: .irreversible
        // Selecting changes nothing until an action runs on the selection.
        case .selectRows: .reversible
        // Leaving the app cannot be undone: sim-use has no launch verb.
        case .press: .leavesApp
        }
    }
}

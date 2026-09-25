/// What to do next, asked before and apart from which element to do it to.
///
/// Asking operation and target separately (as jev-ultrafast does) keeps a scroll or DONE from competing with every
/// tappable element for probability: each competes only with the other operations.
package enum Operation: Sendable, Hashable {
    /// Tap an element.
    case tap
    /// A gesture on an element other than a tap.
    case gesture(ElementGesture)
    /// Type one of the named texts into a field.
    case enterText
    /// A screen-level action.
    case device(SimUseDeviceAction)
    /// Let the app catch up without touching the screen.
    case wait
    /// The goal is visibly satisfied.
    case done
    /// Nothing offered can make progress.
    case blocked

    /// The option name in the `operation` question.
    var optionName: String {
        switch self {
        case .tap: "tap"
        case let .gesture(gesture): gesture.rawValue
        case .enterText: "enter_text"
        case let .device(action): action.optionName
        case .wait: "wait"
        case .done: "done"
        case .blocked: "blocked"
        }
    }

    /// Operations that make the same progress, whose probabilities add up. Rotating either way reaches any heading
    /// (a wrong direction only costs steps), so a goal like "face west" splits Jev between the two without making
    /// rotating any less clear. Zooming in and out have opposite effects and stay apart.
    var equivalents: [Operation] {
        switch self {
        case .gesture(.rotateClockwise), .gesture(.rotateCounterclockwise):
            [.gesture(.rotateClockwise), .gesture(.rotateCounterclockwise)]
        default: [self]
        }
    }

    /// Whether the operation acts on the element `element_target` names: a tap or another element gesture.
    var actsOnElement: Bool {
        switch self {
        case .tap, .gesture: true
        default: false
        }
    }

    /// The criteria Jev reads for this option.
    var optionDescription: String {
        switch self {
        case .tap:
            "Tap one element in `screen.elements` to open, select, press, or toggle it; not for typing into a field, "
                + "which enter_text does, and not for hunting an item `goal` names when no visible element is named in "
                + "`goal`, which scrolling does"
        case let .gesture(gesture): gesture.optionDescription
        case .enterText: "Type one of the named texts into a text field; it taps the field first, so the field needs no separate tap"
        case let .device(action): action.optionDescription
        // Wording follows jev-ultrafast's WAIT rule. A saved memo reached its list about five seconds after the
        // editor closed; without a way to wait, Jev tapped the clock on the blank screen in between.
        case .wait:
            "Wait a moment without touching the screen: only while the screen is loading or blank, or while "
                + "something the last step should produce (a saved item in its list, submitted results) has not "
                + "appeared yet. Prefer a visible element that advances `goal`"
        // A new memo's title was typed and Jev chose DONE (0.52) over the Save button (0.37): typing is not saving.
        case .done:
            "Every part of `goal` is visibly satisfied; stop. Not while text typed into a form still waits for that "
                + "form's save, create, add, or submit button: typing is not saving"
        case .blocked: "No offered operation can make progress; hand over"
        }
    }
}

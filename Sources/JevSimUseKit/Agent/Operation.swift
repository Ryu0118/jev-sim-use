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
        case .done: "done"
        case .blocked: "blocked"
        }
    }

    /// The criteria Jev reads for this option.
    var optionDescription: String {
        switch self {
        case .tap: "Tap one element in `screen.elements` to open, select, press, or toggle it"
        case let .gesture(gesture): gesture.optionDescription
        case .enterText: "Type one of the named texts into a text field"
        case let .device(action): action.optionDescription
        case .done: "Every part of `goal` is visibly satisfied; stop"
        case .blocked: "No offered operation can make progress; hand over"
        }
    }
}

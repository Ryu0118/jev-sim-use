/// One thing the agent can do next. Rebuilt from every observation, so tap aliases
/// always refer to the outline sim-use just cached.
package enum AgentAction: Sendable, Hashable {
    /// Tap the element with alias `@alias`.
    case tap(alias: Int, role: String, label: String)
    /// A gesture other than a plain tap on the element with alias `@alias`.
    case gesture(ElementGesture, alias: Int, role: String, label: String)
    /// A gesture or button press that does not target an element.
    case device(SimUseDeviceAction)
    /// Enter one of the texts the user supplied; Jev picks it by name and never writes text.
    case paste(index: Int, text: InputText)
    /// No offered action fits; the run hands over instead of guessing.
    case noneApplies

    /// The option key sent to Jev. Unique within one catalog.
    var optionName: String {
        switch self {
        case let .tap(alias, _, _): PlanningState.elementID(alias)
        // Never offered as a `next_action` option: Jev picks the gesture and the element in separate questions.
        // The composed name keys loop detection, so one failed long-press does not rule out other gestures.
        case let .gesture(gesture, alias, _, _): "\(gesture.rawValue)_\(PlanningState.elementID(alias))"
        case let .device(action): action.optionName
        case let .paste(index, _): "paste_text_\(index)"
        case .noneApplies: "none_of_these"
        }
    }

    /// The rubric sent to Jev. `nil` for taps: the option name is the element id, and the state already
    /// carries the element's role and label, so repeating them only spends tokens.
    var optionCriteria: String? {
        if case .tap = self {
            nil
        } else {
            optionDescription
        }
    }

    /// A human-readable description, used for progress lines and `history`.
    var optionDescription: String {
        switch self {
        case let .tap(_, role, label): "Tap the \(role) labelled \"\(label)\""
        case let .gesture(gesture, _, role, label): "\(gesture.verb) the \(role) labelled \"\(label)\""
        case let .device(action): action.optionDescription
        case let .paste(_, text): "Enter the \(text.name) into the focused input field"
        case .noneApplies: "Nothing helps, not even scrolling or going back to look elsewhere"
        }
    }
}

extension AgentAction {
    /// How costly the action is when wrong.
    var risk: ActionRisk {
        switch self {
        case .tap: .reversible
        case let .gesture(gesture, _, role, _): gesture.risk(on: role)
        case let .device(action): action.risk
        case .paste: .irreversible
        case .noneApplies: .harmless
        }
    }
}

extension AgentAction: CustomStringConvertible {
    /// What was done, as a fact: the progress line and the `history` entry sent to Jev. Rubrics say when to pick an
    /// option, which is judgment, so they stay out of the state.
    package var description: String {
        switch self {
        case .tap, .gesture: optionDescription
        case let .device(action): action.summary
        case let .paste(_, text): "Enter the \(text.name)"
        case .noneApplies: "Nothing"
        }
    }
}

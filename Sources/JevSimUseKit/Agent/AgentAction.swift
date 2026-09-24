/// One thing the agent can do next. Rebuilt from every observation, so tap aliases
/// always refer to the outline sim-use just cached.
package enum AgentAction: Sendable, Hashable {
    /// Tap the element with alias `@alias`.
    case tap(alias: Int, role: String, label: String)
    /// A gesture or button press that does not target an element.
    case device(SimUseDeviceAction)
    /// Paste one of the texts the user supplied; Jev only chooses, it never writes text.
    case paste(index: Int, text: String)
    /// No offered action fits; the run hands over instead of guessing.
    case noneApplies

    /// The option key sent to Jev. Unique within one catalog.
    var optionName: String {
        switch self {
        case let .tap(alias, _, _): PlanningState.elementID(alias)
        case .device(.revealContentBelow): "scroll_to_reveal_below"
        case .device(.revealContentAbove): "scroll_to_reveal_above"
        case .device(.goBack): "go_back"
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
        case .device(.revealContentBelow): "Scroll to reveal content further down the screen"
        case .device(.revealContentAbove): "Scroll to reveal content further up the screen"
        case .device(.goBack): "Go back to the previous screen"
        case let .paste(_, text): "Paste the text \"\(text)\" into the focused input field"
        case .noneApplies: "None of the other actions would advance the goal"
        }
    }
}

extension AgentAction: CustomStringConvertible {
    /// A human-readable summary, also used as the history entry sent to Jev.
    package var description: String {
        optionDescription
    }
}

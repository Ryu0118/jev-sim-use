/// One thing the agent can do next. Rebuilt from every observation, so tap aliases
/// always refer to the outline sim-use just cached.
public enum AgentAction: Sendable, Hashable {
    /// Tap the element with alias `@alias`.
    case tap(alias: Int, role: String, label: String)
    /// A gesture or button press that does not target an element.
    case device(SimUseDeviceAction)
    /// Paste one of the texts the user supplied; Jev only chooses, it never writes text.
    case paste(index: Int, text: String)

    /// The option key sent to Jev. Unique within one catalog.
    var optionName: String {
        switch self {
        case let .tap(alias, _, _): "tap_\(alias)"
        case .device(.revealContentBelow): "scroll_to_reveal_below"
        case .device(.revealContentAbove): "scroll_to_reveal_above"
        case .device(.goBack): "go_back"
        case let .paste(index, _): "paste_text_\(index)"
        }
    }

    /// The rubric Jev reads for this option.
    var optionDescription: String {
        switch self {
        case let .tap(_, role, label): "Tap the \(role) labelled \"\(label)\""
        case .device(.revealContentBelow): "Scroll to reveal content further down the screen"
        case .device(.revealContentAbove): "Scroll to reveal content further up the screen"
        case .device(.goBack): "Go back to the previous screen"
        case let .paste(_, text): "Paste the text \"\(text)\" into the focused input field"
        }
    }
}

extension AgentAction: CustomStringConvertible {
    /// A human-readable summary, also used as the history entry sent to Jev.
    public var description: String {
        optionDescription
    }
}

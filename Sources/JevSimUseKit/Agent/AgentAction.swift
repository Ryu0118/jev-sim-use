/// One thing the agent can do next. Rebuilt from every observation, so aliases always refer to the outline sim-use
/// just cached.
package enum AgentAction: Sendable, Hashable {
    /// Tap the element with alias `@alias`.
    case tap(alias: Int, role: String, label: String)
    /// A gesture other than a plain tap on the element with alias `@alias`.
    case gesture(ElementGesture, alias: Int, role: String, label: String)
    /// A gesture or button press that does not target an element.
    case device(SimUseDeviceAction)
    /// Tap the field `@field`, then enter one of the texts the user supplied; Jev picks it by name, never writes it.
    case enterText(field: Int, label: String, text: InputText)
    /// Jev judged the goal visibly satisfied.
    case done
    /// Nothing offered fits; the run hands over instead of guessing.
    case noneApplies

    /// A key unique within one screen's choices, used to recognise a repeat of an action that did nothing there.
    var optionName: String {
        switch self {
        case let .tap(alias, _, _): PlanningState.elementID(alias)
        case let .gesture(gesture, alias, _, _): "\(gesture.rawValue)_\(PlanningState.elementID(alias))"
        case let .device(action): action.optionName
        case let .enterText(field, _, text): "enter_\(text.name)_\(PlanningState.elementID(field))"
        case .done: "done"
        case .noneApplies: "blocked"
        }
    }
}

extension AgentAction {
    /// How costly the action is when wrong.
    var risk: ActionRisk {
        switch self {
        case let .tap(_, _, label): ActionCatalog.isDestructive(label) ? .irreversible : .reversible
        case let .gesture(gesture, _, _, _): gesture.risk
        case let .device(action): action.risk
        case .enterText: .irreversible
        case .done, .noneApplies: .harmless
        }
    }
}

extension AgentAction: CustomStringConvertible {
    /// What was done, as a fact: the progress line and the `history` entry sent to Jev.
    package var description: String {
        switch self {
        case let .tap(_, role, label): "Tap the \(role) labelled \"\(label)\""
        case let .gesture(gesture, _, role, label): "\(gesture.verb) the \(role) labelled \"\(label)\""
        case let .device(action): action.summary
        case let .enterText(_, label, text): "Enter the \(text.name) into \"\(label)\""
        case .done: "Done"
        case .noneApplies: "Nothing"
        }
    }
}

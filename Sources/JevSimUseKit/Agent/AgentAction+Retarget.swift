extension AgentAction {
    /// The same action aimed at the same element in `fresh`, a later reading of `planned`; `nil` for an action that
    /// does not target an element, or whose element moved, changed, or is gone there.
    func retargeted(from planned: UISnapshot, to fresh: UISnapshot) -> AgentAction? {
        switch self {
        case let .tap(alias, role, label):
            planned.counterpart(of: alias, in: fresh).map { .tap(alias: $0, role: role, label: label) }
        case let .gesture(gesture, alias, role, label):
            planned.counterpart(of: alias, in: fresh).map { .gesture(gesture, alias: $0, role: role, label: label) }
        case let .enterText(field, label, text):
            planned.counterpart(of: field, in: fresh).map { .enterText(field: $0, label: label, text: text) }
        case .device, .wait, .done, .noneApplies:
            nil
        }
    }
}

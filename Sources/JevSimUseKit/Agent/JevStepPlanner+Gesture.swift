import Jev

extension JevStepPlanner {
    static let gestureOption = "gesture_on_element"
    static let gestureOptionCriteria = """
    Do something other than a plain tap to one element in `screen.elements`: press and hold it, swipe on it, pinch it, \
    or rotate it
    """
    static let gestureQuestion = "element_gesture"
    static let targetQuestion = "gesture_target"

    /// Asking for the gesture and its element separately keeps the option count at elements + gestures instead of
    /// their product. Both questions state their premise, because they run without seeing `next_action`'s answer.
    static func gestureQuestions(_ targets: [GestureTarget]) throws -> [String: Question] {
        let premise = "Suppose the next step toward `goal` is a gesture on one element other than a plain tap."
        let gesture = try Question(
            instructions: "\(premise) Which gesture should it be?",
            kind: .choice(ElementGesture.allCases.map { ChoiceOption($0.rawValue, $0.optionDescription) }),
        )
        let target = try Question(
            instructions: "\(premise) Which element in `screen.elements` should receive it? Options are element ids.",
            kind: .choice(targets.map { ChoiceOption(PlanningState.elementID($0.alias), nil) }),
        )
        return [gestureQuestion: gesture, targetQuestion: target]
    }

    /// The gesture action the speculative answers compose, and its support: the least certain of the three choices,
    /// so a confident gate with an unsure element does not act.
    static func composeGesture(
        _ response: JevResponse,
        gateSupport: Double,
        targets: [GestureTarget],
    ) throws -> (action: AgentAction, support: Double) {
        guard case let .choice(gestureChoice) = response.answers[gestureQuestion],
              case let .choice(targetChoice) = response.answers[targetQuestion]
        else { throw PlanningError.missingChoice }
        guard let gesture = ElementGesture(rawValue: gestureChoice.value) else {
            throw PlanningError.unknownChoice(gestureChoice.value)
        }
        guard let target = targets.first(where: { PlanningState.elementID($0.alias) == targetChoice.value }) else {
            throw PlanningError.unknownChoice(targetChoice.value)
        }
        return (target.action(gesture), min(gateSupport, gestureChoice.confidence, targetChoice.confidence))
    }
}

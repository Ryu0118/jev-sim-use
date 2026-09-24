/// The `state` sent to Jev. The outline is sim-use's compact text form, which is
/// what sim-use recommends feeding a model.
struct PlanningState: Encodable, Sendable {
    let goal: String
    let platform: String
    let screen: String
    let previousActions: [String]

    enum CodingKeys: String, CodingKey {
        case goal
        case platform
        case screen
        case previousActions = "previous_actions"
    }

    init(_ request: PlanRequest) {
        goal = request.goal
        platform = request.snapshot.platform
        screen = request.snapshot.outline
        previousActions = request.history
    }
}

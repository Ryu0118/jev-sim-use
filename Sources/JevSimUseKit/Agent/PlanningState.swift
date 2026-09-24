/// The `state` sent to Jev: named fields, with every on-screen element listed once under `screen.elements`.
///
/// Tap options are named by element id, so the rubric does not repeat labels that the state already carries.
struct PlanningState: Encodable, Sendable {
    let goal: String
    let platform: String
    let screen: Screen
    let history: [HistoryEntry]

    init(_ request: PlanRequest) {
        goal = request.goal
        platform = request.snapshot.platform
        screen = Screen(request.snapshot)
        history = request.history
    }

    /// The id an element carries in the state, which is also its tap option name.
    static func elementID(_ alias: Int) -> String {
        "e\(alias)"
    }
}

/// The `state` sent to Jev: named fields, with every on-screen element listed once under `screen.elements`.
///
/// Tap options are named by element id, so the rubric does not repeat labels that the state already carries.
/// A session keeps growing `history` and `notes`, so only the most recent ones are sent to stay within Jev's
/// 32k-token state limit.
struct PlanningState: Encodable, Sendable {
    static let historyLimit = 20
    static let notesLimit = 10

    let goal: String
    let notes: [String]
    let platform: String
    let screen: Screen
    let history: [HistoryEntry]

    init(_ request: PlanRequest) {
        goal = request.goal
        notes = Array(request.notes.suffix(Self.notesLimit))
        platform = request.snapshot.platform
        screen = Screen(request.snapshot)
        history = Array(request.history.suffix(Self.historyLimit))
    }

    /// The id an element carries in the state, which is also its tap option name.
    static func elementID(_ alias: Int) -> String {
        "e\(alias)"
    }
}

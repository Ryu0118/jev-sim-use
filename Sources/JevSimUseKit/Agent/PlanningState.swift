/// The `state` sent to Jev: named fields, with every on-screen element listed once under `screen.elements`.
///
/// Tap options are named by element id, so the rubric does not repeat labels that the state already carries.
/// A session keeps growing `history` and `notes`, so only the most recent ones are sent to stay within Jev's
/// 32k-token state limit.
struct PlanningState: Encodable, Sendable {
    static let historyLimit = 20
    static let notesLimit = 10

    /// How to decide, built by `PlanningRules` from the step's offered operations; every question points at it with
    /// `JevStepPlanner.rulesPointer`. JSONEncoder does not keep key order, so this cannot be pinned before the data.
    let rules: String
    let goal: String
    let notes: [String]
    let platform: String
    let screen: Screen
    let history: [Step]

    init(_ request: PlanRequest) {
        rules = PlanningRules(operations: request.menu.operations).text
        goal = request.goal
        notes = Array(request.notes.suffix(Self.notesLimit))
        platform = request.snapshot.platform
        screen = Screen(
            request.snapshot, texts: request.menu.texts, hints: request.includesHints, openedBy: request.openedBy,
        )
        history = request.history.suffix(Self.historyLimit).map(Step.init)
    }

    /// One earlier step, with its effect in words so Jev can tell a dead end from progress.
    struct Step: Encodable, Sendable {
        let step: Int
        let action: String
        let result: String?

        init(_ entry: HistoryEntry) {
            step = entry.step
            action = entry.action
            result = entry.screenChanged.map { $0 ? "screen changed" : "no visible effect" }
        }
    }

    /// The id an element carries in the state, which is also its tap option name.
    static func elementID(_ alias: Int) -> String {
        "e\(alias)"
    }
}

/// Mutable bookkeeping for one run: history, stall detection, crash detection, and actions that did nothing.
struct AgentProgress: Sendable {
    private(set) var history: [HistoryEntry] = []
    private(set) var steps = 0
    /// Option names that left the current screen unchanged; code drops them instead of asking Jev to remember.
    private(set) var ineffectiveActions: Set<String> = []
    private var previousOutline: String?
    private var lastActionName: String?
    private var unchangedCount = 0
    private var pendingDisappearances: [String] = []

    /// Returns an outcome when the observation means the run must stop.
    mutating func record(_ observation: ScreenObservation, stallLimit: Int) -> AgentOutcome? {
        let disappeared = pendingDisappearances + observation.disappearedApps
        if !disappeared.isEmpty {
            return .appCrashed(detail: "the app disappeared (\(disappeared.joined(separator: ", "))).")
        }
        if let dialog = observation.snapshot.crashDialog {
            return .appCrashed(detail: "a crash dialog is on screen (\(dialog.title ?? "untitled")).")
        }
        let outline = observation.snapshot.outline
        let unchanged = previousOutline == outline
        if let last = history.indices.last {
            history[last].screenChanged = !unchanged
        }
        if unchanged {
            lastActionName.map { _ = ineffectiveActions.insert($0) }
        } else {
            ineffectiveActions = []
        }
        unchangedCount = unchanged ? unchangedCount + 1 : 0
        previousOutline = outline
        return unchangedCount >= stallLimit ? .stalled(steps: steps) : nil
    }

    mutating func recordAction(_ action: AgentAction, disappeared: [String]) {
        steps += 1
        history.append(HistoryEntry(step: steps, action: action.description, screenChanged: nil))
        lastActionName = action.optionName
        pendingDisappearances = disappeared
    }
}

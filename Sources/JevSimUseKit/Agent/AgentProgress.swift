/// Mutable bookkeeping for one run: history, loop detection, crash detection, and actions already tried.
struct AgentProgress: Sendable {
    private(set) var history: [HistoryEntry] = []
    private(set) var steps = 0
    private var currentOutline: String?
    private var lastActionName: String?
    /// Option names already tried on each screen. Repeating an action on an identical screen cannot help, and
    /// screens can alternate (a scroll that bounces), so this is keyed by screen rather than by the previous one.
    private var triedActions: [String: Set<String>] = [:]
    private var revisitCount = 0
    private var pendingDisappearances: [String] = []

    /// Options code drops on the current screen instead of asking Jev to remember them.
    var ineffectiveActions: Set<String> {
        currentOutline.flatMap { triedActions[$0] } ?? []
    }

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
        if let previous = currentOutline, let action = lastActionName {
            triedActions[previous, default: []].insert(action)
            history[history.count - 1].screenChanged = previous != outline
        }
        let revisited = triedActions[outline] != nil || currentOutline == outline
        revisitCount = revisited ? revisitCount + 1 : 0
        currentOutline = outline
        return revisitCount >= stallLimit ? .stalled(steps: steps) : nil
    }

    mutating func recordAction(_ action: AgentAction, disappeared: [String]) {
        steps += 1
        history.append(HistoryEntry(step: steps, action: action.description, screenChanged: nil))
        lastActionName = action.optionName
        pendingDisappearances = disappeared
    }
}

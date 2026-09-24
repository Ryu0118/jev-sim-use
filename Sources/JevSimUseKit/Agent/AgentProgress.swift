/// Mutable bookkeeping for one run: history, loop detection, crash detection, and actions already tried.
struct AgentProgress: Sendable {
    private(set) var history: [HistoryEntry]
    /// Actions taken in this run; `maxSteps` limits this, not the continued history.
    private(set) var steps = 0
    private let stepOffset: Int
    private var currentOutline: String?
    private var lastActionName: String?
    /// Option names already tried on each screen. Repeating an action on an identical screen cannot help, and
    /// screens can alternate (a scroll that bounces), so this is keyed by screen rather than by the previous one.
    private var triedActions: [String: Set<String>] = [:]
    private var revisitCount = 0
    private var pendingDisappearances: [String] = []

    init(history: [HistoryEntry] = []) {
        self.history = history
        stepOffset = history.last?.step ?? 0
    }

    /// The number the next action gets, counting the continued history.
    var nextStep: Int {
        stepOffset + steps + 1
    }

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
        let outline = observation.snapshot.identity
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
        history.append(HistoryEntry(step: nextStep, action: action.description, screenChanged: nil))
        steps += 1
        lastActionName = action.optionName
        pendingDisappearances = disappeared
    }
}

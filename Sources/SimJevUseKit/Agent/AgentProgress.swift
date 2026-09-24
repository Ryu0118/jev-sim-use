/// Mutable bookkeeping for one run: history, stall detection, crash detection.
struct AgentProgress: Sendable {
    private(set) var history: [String] = []
    private(set) var steps = 0
    private var previousOutline: String?
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
        unchangedCount = previousOutline == outline ? unchangedCount + 1 : 0
        previousOutline = outline
        return unchangedCount >= stallLimit ? .stalled(steps: steps) : nil
    }

    mutating func recordAction(_ action: AgentAction, disappeared: [String]) {
        steps += 1
        history.append(action.description)
        pendingDisappearances = disappeared
    }
}

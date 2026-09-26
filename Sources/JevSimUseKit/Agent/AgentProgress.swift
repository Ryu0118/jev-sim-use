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
    private var currentTitle: String?
    private var lastTapLabel: String?
    /// The label of the last tap, when it changed the screen: what opened a menu that is now showing.
    private(set) var menuOpener: String?
    /// Elements tapped on a screen (by title) that led to another screen: branches already explored. Coming back to
    /// that title means the branch did not finish the goal, and the scroll position there may differ, so the
    /// identity-keyed `triedActions` cannot catch a second visit.
    private var exploredBranches: [String: Set<String>] = [:]
    private var pendingDisappearances: [String] = []
    private var currentSkeleton = ""
    /// The action taken back to back, the skeletons of the screens it was taken on, and how many times in a row.
    private var repeatRun: (action: String, skeletons: Set<String>, count: Int)?

    /// How many times in a row one action may be taken from screens showing the same elements before it is refused.
    ///
    /// A row tapped 26 times in a row at 0.64-0.98 never opened; each tap counted as a change because a relative
    /// time on the screen ticked, so the identity-keyed `triedActions` never caught it.
    static let repeatLimit = 3

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

    /// Labels of elements whose branch was already explored from a screen with the current title.
    var exploredElements: Set<String> {
        currentTitle.flatMap { exploredBranches[$0] } ?? []
    }

    /// Whether `action` would be the same action once more after `repeatLimit` in a row, on a screen showing the
    /// same elements (`UISnapshot.skeleton`) as one it was already taken on: it did not get anywhere, whether the
    /// screen stayed or alternated. Waiting is exempt: waiting out a slow save is how it works.
    func isFutileRepeat(_ action: AgentAction) -> Bool {
        guard action != .wait, let run = repeatRun, run.action == action.description else { return false }
        return run.count >= Self.repeatLimit && run.skeletons.contains(currentSkeleton)
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
        let title = observation.snapshot.title
        if let previousTitle = currentTitle, let label = lastTapLabel, previousTitle != title {
            exploredBranches[previousTitle, default: []].insert(label)
        }
        currentTitle = title
        currentSkeleton = observation.snapshot.skeleton
        if let label = lastTapLabel, currentOutline != outline {
            menuOpener = label
        }
        lastTapLabel = nil
        let revisited = triedActions[outline] != nil || currentOutline == outline
        revisitCount = revisited ? revisitCount + 1 : 0
        currentOutline = outline
        return revisitCount >= stallLimit ? .stalled(steps: steps) : nil
    }

    mutating func recordAction(_ action: AgentAction, disappeared: [String]) {
        history.append(HistoryEntry(step: nextStep, action: action.description, screenChanged: nil))
        steps += 1
        lastActionName = action.optionName
        repeatRun = if let run = repeatRun, run.action == action.description {
            (run.action, run.skeletons.union([currentSkeleton]), run.count + 1)
        } else {
            (action.description, [currentSkeleton], 1)
        }
        menuOpener = nil
        if case let .tap(_, _, label) = action {
            lastTapLabel = label
        }
        pendingDisappearances = disappeared
    }
}

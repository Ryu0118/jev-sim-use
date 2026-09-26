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
    /// Each element's value and states on the current screen, by `UIEntry.stateKey`.
    private var currentStates: [String: String] = [:]
    /// Elements seen changing between two readings with no action between (a relative time, a timer): their changes
    /// are not an action's effect.
    private var tickingElements: Set<String> = []
    /// The action taken back to back, the skeletons of the screens it was taken on, and the element states before the
    /// first and after each one.
    private var repeatRun: (action: String, skeletons: Set<String>, states: [[String: String]])?
    /// Whether the next recorded screen is the one the last action left, to add to `repeatRun`.
    private var awaitsRepeatState = false

    /// How many repeats in a row may leave the screen in a state already seen in the run before the next is refused.
    ///
    /// A row tapped 26 times in a row at 0.64-0.98 never opened; each tap counted as a change because a relative
    /// time on the row ticked, so the identity-keyed `triedActions` never caught it. A counter's taps, by contrast,
    /// each leave a new value, and a switch flipped back and forth returns to states already seen.
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

    /// Whether `action` would be the same action once more after its last `repeatLimit` repeats each left the screen
    /// in a state already seen in the run, on a screen showing the same elements (`UISnapshot.skeleton`) as one it was
    /// taken on: it did not get anywhere, whether the screen stayed or alternated. States leave out elements that
    /// tick on their own. Waiting is exempt: waiting out a slow save is how it works.
    func isFutileRepeat(_ action: AgentAction) -> Bool {
        guard action != .wait, let run = repeatRun, run.action == action.description,
              run.skeletons.contains(currentSkeleton)
        else { return false }
        let states = run.states.map { $0.filter { !tickingElements.contains($0.key) } }
        var stale = 0
        for index in states.indices.dropFirst() {
            stale = states[..<index].contains(states[index]) ? stale + 1 : 0
        }
        return stale >= Self.repeatLimit
    }

    /// Notes `snapshot`, a reading taken with no action since the last recorded one: an element whose value or states
    /// changed between the two changes on its own. After an action whose effect had not shown yet, a change may be
    /// that effect arriving late, so nothing is noted then.
    mutating func noteReading(_ snapshot: UISnapshot) {
        guard history.last?.screenChanged != false else { return }
        for (key, state) in Self.states(of: snapshot) where currentStates[key].map({ $0 != state }) == true {
            tickingElements.insert(key)
        }
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
        currentStates = Self.states(of: observation.snapshot)
        if awaitsRepeatState {
            repeatRun?.states.append(currentStates)
            awaitsRepeatState = false
        }
        if let label = lastTapLabel, currentOutline != outline {
            menuOpener = label
        }
        lastTapLabel = nil
        let revisited = triedActions[outline] != nil || currentOutline == outline
        revisitCount = revisited ? revisitCount + 1 : 0
        currentOutline = outline
        return revisitCount >= stallLimit ? .stalled(steps: steps) : nil
    }

    mutating func recordAction(_ action: AgentAction, disappeared: [String], timing: StepTiming? = nil) {
        history.append(HistoryEntry(
            step: nextStep, action: action.description, screenChanged: nil,
            effectMayNotShow: action.effectMayNotShow ? true : nil, timing: timing,
        ))
        steps += 1
        lastActionName = action.optionName
        repeatRun = if let run = repeatRun, run.action == action.description {
            (run.action, run.skeletons.union([currentSkeleton]), run.states)
        } else {
            (action.description, [currentSkeleton], [currentStates])
        }
        awaitsRepeatState = true
        menuOpener = nil
        if case let .tap(_, _, label) = action {
            lastTapLabel = label
        }
        pendingDisappearances = disappeared
    }

    /// Each element's value and states, by role, label, and identifier; elements alike in all three are numbered in
    /// reading order.
    private static func states(of snapshot: UISnapshot) -> [String: String] {
        var states: [String: String] = [:]
        for entry in snapshot.entries ?? [] {
            let base = [entry.role, entry.label, entry.uniqueId ?? ""].joined(separator: "|")
            var key = base
            var index = 1
            while states[key] != nil {
                index += 1
                key = "\(base)#\(index)"
            }
            states[key] = [entry.value ?? "", entry.states.joined(separator: ",")].joined(separator: "|")
        }
        return states
    }
}

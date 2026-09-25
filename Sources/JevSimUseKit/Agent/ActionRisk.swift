/// How costly an action is when Jev picked the wrong one.
package enum ActionRisk: Sendable, Hashable {
    /// Changes nothing in the app and costs one step (scrolling, going back, zooming, rotating).
    case harmless
    /// Changes something going back can undo (a tap, an edge swipe).
    case reversible
    /// Cannot be undone from inside the app (tapping a destructive control).
    case irreversible
    /// Leaves the app or locks the device: sim-use has no launch verb, so the run cannot come back.
    case leavesApp
}

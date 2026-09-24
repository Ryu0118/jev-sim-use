/// How costly an action is when Jev picked the wrong one.
package enum ActionRisk: Sendable, Hashable {
    /// Changes nothing in the app and costs one step (scrolling, going back).
    case harmless
    /// Changes something going back can undo (a tap, an edge swipe).
    case reversible
    /// Cannot be undone from inside the app (pasting text, leaving the app, locking the device).
    case irreversible
}

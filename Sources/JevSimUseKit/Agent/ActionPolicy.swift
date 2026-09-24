import Jev

/// When to act on Jev's chosen action. Kept apart from the goal policy: a noul threshold does not carry over to a
/// choice, and `--min-confidence` should not move the goal-reached band.
package struct ActionPolicy: Sendable, Hashable {
    /// Support at or above which acting needs no note.
    package static let confidentSupport = RoutingPolicy.default.autoAtOrAbove
    /// Pasting text, leaving the app, or locking the device is not undone by going back, so it needs this much.
    package static let irreversibleMinimum = RoutingPolicy.default.autoAtOrAbove
    /// Scrolling and going back change nothing in the app and cost one step when wrong, so they need less.
    package static let harmlessMaximum = 0.3

    /// Jev's DONE needs this much before the run claims success; below it the run stops as probably done.
    package static let doneMinimum = RoutingPolicy.default.escalateBelow
    /// A `finishes` answer at or above this, followed by a screen that changed, ends the run without another request.
    package static let finishMinimum = RoutingPolicy.default.autoAtOrAbove

    /// Hand over below this support for reversible actions (taps, scrolls, going back).
    package var minimumSupport: Double

    package init(minimumSupport: Double = RoutingPolicy.default.escalateBelow) {
        self.minimumSupport = minimumSupport
    }

    /// The support `action` needs before it runs; higher for actions going back cannot undo.
    package func requiredSupport(for action: AgentAction) -> Double {
        switch action.risk {
        case .harmless: min(minimumSupport, Self.harmlessMaximum)
        case .reversible: minimumSupport
        case .irreversible: max(minimumSupport, Self.irreversibleMinimum)
        }
    }
}

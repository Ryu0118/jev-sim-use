import Jev

/// When to act on Jev's chosen action. Kept apart from the goal policy: a noul threshold does not carry over to a
/// choice, and `--min-confidence` should not move the goal-reached band.
package struct ActionPolicy: Sendable, Hashable {
    /// Support at or above which acting needs no note.
    package static let confidentSupport = RoutingPolicy.default.autoAtOrAbove
    /// Pasting text is not undone by going back, so it needs at least this much support.
    package static let irreversibleMinimum = RoutingPolicy.default.autoAtOrAbove

    /// Hand over below this support for reversible actions (taps, scrolls, going back).
    package var minimumSupport: Double

    package init(minimumSupport: Double = RoutingPolicy.default.escalateBelow) {
        self.minimumSupport = minimumSupport
    }

    /// The support `action` needs before it runs; higher for actions going back cannot undo.
    package func requiredSupport(for action: AgentAction) -> Double {
        if case .paste = action {
            max(minimumSupport, Self.irreversibleMinimum)
        } else {
            minimumSupport
        }
    }
}

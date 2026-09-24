import Jev

/// When to act on Jev's chosen action. Kept apart from the goal policy: a noul threshold does not carry over to a
/// choice, and `--min-confidence` should not move the goal-reached band.
package struct ActionPolicy: Sendable, Hashable {
    /// Support at or above which acting needs no note.
    package static let confidentSupport = RoutingPolicy.default.autoAtOrAbove
    /// Pasting text, leaving the app, or locking the device is not undone by going back, so it needs this much.
    package static let irreversibleMinimum = RoutingPolicy.default.autoAtOrAbove
    /// Scrolling and going back change nothing in the app and cost one step when wrong, so exploring needs less.
    package static let harmlessMaximum = 0.3

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

import Jev

/// When to act on Jev's chosen action. Kept apart from the goal policy: a noul threshold does not carry over to a
/// choice, and `--min-confidence` should not move the goal-reached band.
package struct ActionPolicy: Sendable, Hashable {
    /// Support at or above which acting needs no note.
    package static let confidentSupport = RoutingPolicy.default.autoAtOrAbove
    /// Leaving the app, locking the device, or tapping a destructive control is not undone by going back, so it needs
    /// this much. jev-use gates destructive picks at 0.6 as well; the earlier 0.85 stopped correct steps at 0.65-0.84.
    package static let irreversibleMinimum = 0.6
    /// Scrolling and going back change nothing in the app and cost one step when wrong, so they need less.
    package static let harmlessMaximum = 0.3

    /// Jev's DONE needs this much before the run claims success; below it the run stops as probably done.
    /// Set from real runs: correct DONEs scored 0.58-0.99, the one wrong DONE 0.49.
    package static let doneMinimum = 0.55
    /// A `finishes` answer at or above this, followed by a screen that changed, ends the run without another request.
    /// Set from real runs: actions that did finish scored 0.78-0.95, actions that did not at most 0.48.
    package static let finishMinimum = 0.75

    /// The default bar for reversible actions, set from real runs: correct taps scored 0.59 and up, wrong ones at most
    /// 0.52. A wrong reversible tap costs a step and shows up in `history` as leading nowhere.
    package static let defaultMinimumSupport = 0.55

    /// Hand over below this support for reversible actions (taps, scrolls, going back).
    package var minimumSupport: Double

    package init(minimumSupport: Double = Self.defaultMinimumSupport) {
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

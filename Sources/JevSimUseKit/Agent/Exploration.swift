/// What code does when Jev judges that nothing on the current screen advances the goal.
///
/// Jev picks well among what is on screen but does not search, so the loop searches deterministically: look
/// further down the screen, then back up one level. Each is tried once per screen (see `AgentProgress`).
enum Exploration {
    static let order: [AgentAction] = [.device(.revealContentBelow), .device(.goBack)]

    /// The next exploration step not yet tried on this screen, or `nil` when the screen is exhausted.
    static func next(excluding tried: Set<String>) -> AgentAction? {
        order.first { !tried.contains($0.optionName) }
    }
}

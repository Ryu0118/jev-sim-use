extension UISnapshot {
    /// How far an element may sit from where it was planned and still count as the same target, in points.
    static let counterpartTolerance = 4.0

    /// The alias in `fresh` of the element `@alias` names here: the one element with the same role, label,
    /// identifier, and states whose frame is within `counterpartTolerance`. Values are not compared, since some change
    /// on their own (a relative time); the loop requires identical readings where a value change could be the last
    /// action's effect. `nil` when it moved, changed, or is gone,
    /// or when several match, because sim-use would then tap whatever took its place.
    func counterpart(of alias: Int, in fresh: UISnapshot) -> Int? {
        guard let entry = entry(alias: alias), let frame = entry.frame else { return nil }
        let matches = (fresh.entries ?? []).filter { other in
            guard let otherFrame = other.frame else { return false }
            return other.role == entry.role && other.label == entry.label && other.uniqueId == entry.uniqueId
                && other.states.filter(Self.isState) == entry.states.filter(Self.isState)
                && abs(otherFrame.x - frame.x) <= Self.counterpartTolerance
                && abs(otherFrame.y - frame.y) <= Self.counterpartTolerance
                && abs(otherFrame.width - frame.width) <= Self.counterpartTolerance
                && abs(otherFrame.height - frame.height) <= Self.counterpartTolerance
        }
        return matches.count == 1 ? matches[0].aliases.alias : nil
    }

    /// sim-use repeats the value among the states (`value="…"`); the other states (selected, disabled) are compared.
    private static func isState(_ state: String) -> Bool {
        !state.hasPrefix("value=")
    }
}

extension UISnapshot {
    /// Whether an element identical to `entry` in role, label, identifier, value, and states is on screen, wherever
    /// it sits: the element an action targeted, still exactly as it was.
    func showsUnchanged(_ entry: UIEntry) -> Bool {
        (entries ?? []).contains { other in
            other.role == entry.role && other.label == entry.label && other.uniqueId == entry.uniqueId
                && other.value == entry.value && other.states == entry.states
        }
    }
}

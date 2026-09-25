extension UISnapshot {
    /// How far an element may sit from where it was planned and still count as the same target, in points.
    static let counterpartTolerance = 4.0

    /// The alias in `fresh` of the element `@alias` names here: the one element with the same role, label, value,
    /// identifier, and states whose frame is within `counterpartTolerance`. `nil` when it moved, changed, or is gone,
    /// or when several match, because sim-use would then tap whatever took its place.
    func counterpart(of alias: Int, in fresh: UISnapshot) -> Int? {
        guard let entry = entry(alias: alias), let frame = entry.frame else { return nil }
        let matches = (fresh.entries ?? []).filter { other in
            guard let otherFrame = other.frame else { return false }
            return other.role == entry.role && other.label == entry.label && other.value == entry.value
                && other.uniqueId == entry.uniqueId && other.states == entry.states
                && abs(otherFrame.x - frame.x) <= Self.counterpartTolerance
                && abs(otherFrame.y - frame.y) <= Self.counterpartTolerance
                && abs(otherFrame.width - frame.width) <= Self.counterpartTolerance
                && abs(otherFrame.height - frame.height) <= Self.counterpartTolerance
        }
        return matches.count == 1 ? matches[0].aliases.alias : nil
    }
}

extension UISnapshot {
    /// The element floating over `entry`'s centre, if any.
    ///
    /// sim-use taps an element's centre. A row scrolled under iOS's floating search bar had its centre inside the bar,
    /// so a tap opened search, and a tap on the row's uncovered sliver was swallowed too: such a row must be scrolled
    /// into view first. Elements that contain the whole target (the screen-sized group) or are its children (inside
    /// it and deeper in the tree, like a row's own label) do not count; the search bar lay inside the row's frame but
    /// shallower in the tree.
    func cover(of entry: UIEntry) -> UIEntry? {
        guard let target = entry.frame else { return nil }
        let center = target.center
        return (entries ?? []).first { other in
            guard let frame = other.frame, frame != target, !frame.contains(target) else { return false }
            let isChild = target.contains(frame) && (other.depth ?? 0) > (entry.depth ?? 0)
            return !isChild && frame.x <= center.x && center.x <= frame.x + frame.width
                && frame.y <= center.y && center.y <= frame.y + frame.height
        }
    }
}

extension ElementFrame {
    /// Whether `other` lies entirely inside this frame.
    func contains(_ other: ElementFrame) -> Bool {
        x <= other.x && y <= other.y && other.x + other.width <= x + width && other.y + other.height <= y + height
    }
}

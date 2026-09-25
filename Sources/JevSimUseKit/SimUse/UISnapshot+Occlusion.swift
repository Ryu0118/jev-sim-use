extension UISnapshot {
    /// The element floating over `entry`'s centre, if any.
    ///
    /// sim-use taps an element's centre. A row scrolled under iOS's floating search bar had its centre inside the bar,
    /// so a tap opened search, and a tap on the row's uncovered sliver was swallowed too: such a row must be scrolled
    /// into view first. Elements that contain the whole target (the screen-sized group) or are its children (inside
    /// it and deeper in the tree, like a row's own label) do not count; the search bar lay inside the row's frame but
    /// shallower in the tree. A shallower element overlapping the row covers it even off its centre: the bar's glass
    /// reaches past its text field's frame and swallowed a tap on a row whose centre sat just above that frame.
    ///
    /// Bars (a tab bar, toolbar, navigation bar, or another named group) are drawn over the content that scrolls
    /// beneath them, so content never covers an element inside one: a history row scrolled under the tab bar had its
    /// frame over a tab's centre, and the tab was wrongly treated as covered.
    func cover(of entry: UIEntry) -> UIEntry? {
        guard let target = entry.frame else { return nil }
        let center = target.center
        let bar = entry.region.flatMap { Self.barKinds.contains($0.kind) ? $0 : nil }
        return (entries ?? []).first { other in
            guard let frame = other.frame, frame != target, !frame.contains(target) else { return false }
            if let bar, other.region != bar {
                return false
            }
            let isChild = target.contains(frame) && (other.depth ?? 0) > (entry.depth ?? 0)
            let floatsOver = (other.depth ?? 0) < (entry.depth ?? 0) && frame.overlaps(target)
            return !isChild && (floatsOver || frame.x <= center.x && center.x <= frame.x + frame.width
                && frame.y <= center.y && center.y <= frame.y + frame.height)
        }
    }
}

extension UISnapshot {
    /// The scroll that brings `entry` where a tap at its centre reaches it, or `nil` when it already does: an element
    /// under an overlay, or one whose centre lies past the screen's edge (a settings switch below the tab bar, whose
    /// tap landed off screen).
    func revealingScroll(for entry: UIEntry) -> SimUseDeviceAction? {
        let bottom = screen.map { $0.y + $0.height }
            ?? (entries ?? []).compactMap(\.frame).map { $0.y + $0.height }.max() ?? 0
        if let cover = cover(of: entry) {
            // An overlay in the lower half (a bottom search bar) needs the row moved up, which reveals content below.
            // Comparing the overlay with the row itself flipped when the row sat a few points lower.
            return (cover.frame?.center.y ?? 0) >= bottom / 2 ? .revealContentBelow : .revealContentAbove
        }
        guard let center = entry.frame?.center else { return nil }
        if center.y >= bottom {
            return .revealContentBelow
        }
        return center.y < (screen?.y ?? 0) ? .revealContentAbove : nil
    }
}

extension UISnapshot {
    /// sim-use's region kinds for containers drawn over the scrolling content.
    static let barKinds: Set = ["NavBar", "TabBar", "Toolbar", "Group"]
}

extension ElementFrame {
    /// Whether `other` lies entirely inside this frame.
    func contains(_ other: ElementFrame) -> Bool {
        x <= other.x && y <= other.y && other.x + other.width <= x + width && other.y + other.height <= y + height
    }

    /// Whether the two frames share some area; frames that only touch along an edge do not.
    func overlaps(_ other: ElementFrame) -> Bool {
        x < other.x + other.width && other.x < x + width && y < other.y + other.height && other.y < y + height
    }
}

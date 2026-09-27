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
    /// frame over a tab's centre, and the tab was wrongly treated as covered. A named group can also be scrolling
    /// content under a shallower header, so an element outside it still covers it when shallower. A tab is known by its trait rather than
    /// its band: sim-use puts an unlabelled tab bar in the bottom band, which the rows scrolled under it share.
    ///
    /// On iOS a top bar's background reaches from the screen's top edge down to its items, but only the items are in
    /// the tree. A row scrolled up above a shallower top-band item (the inline title or back button) lies under that
    /// background, so it is covered even where it overlaps no item: a row with its centre in the status bar strip was
    /// tapped there, and nothing happened. Android reports clipped frames, so its rows never reach under a bar.
    func cover(of entry: UIEntry) -> UIEntry? {
        guard let target = entry.frame, !entry.isTabButton else { return nil }
        let center = target.center
        let bar = entry.region.flatMap { Self.barKinds.contains($0.kind) || $0.kind == Self.labelledGroupKind ? $0 : nil }
        return (entries ?? []).first { other in
            guard let frame = other.frame, frame != target, !frame.contains(target) else { return false }
            let shallower = (other.depth ?? 0) < (entry.depth ?? 0)
            // Content outside the bar or group scrolls beneath it, but a shallower element is drawn over it: a
            // calendar's timeline is a labelled group, and an event row scrolled under the week strip was tapped on
            // the strip's date header three times.
            if let bar, other.region != bar, !shallower {
                return false
            }
            let isChild = target.contains(frame) && (other.depth ?? 0) > (entry.depth ?? 0)
            let underTopBar = shallower && platform == SimUseContract.Platform.ios
                && other.region.map { Self.topBarKinds.contains($0.kind) } == true && center.y < frame.y
            let floatsOver = shallower && (frame.overlaps(target) || underTopBar)
            // A deeper element lies beneath: a list row under a floating create button (depth 1 over rows at 2)
            // held the button's centre, and the button was scrolled away instead of tapped.
            let beneath = (other.depth ?? 0) > (entry.depth ?? 0)
            return !isChild && !beneath && (floatsOver || frame.x <= center.x && center.x <= frame.x + frame.width
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
    /// sim-use's region kinds for bars drawn over the scrolling content. iOS reports none of them: its tab bar items
    /// carry the `TabButton` trait instead.
    static let barKinds: Set = ["NavBar", "TabBar", "Toolbar"]

    /// sim-use's region kind for a labelled container, such as a toolbar, but also a group of ordinary content.
    static let labelledGroupKind = "Group"

    /// sim-use's region kinds at the top of the screen, where a navigation bar's items sit.
    static let topBarKinds: Set = ["Top", "NavBar"]
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

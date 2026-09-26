extension UISnapshot {
    /// The full-screen button behind a pop-up menu or popover that dismisses it, or `nil` when there is none.
    ///
    /// iOS covers the screen with it while a menu is open, labelled like "dismiss", and lists the menu's items above
    /// it (deeper in the tree, inside its frame). Offered as a target, it drew Jev away from the menu's items: 5 of 10
    /// runs tapped it (0.35-0.40) or picked the right item too unsure to act (0.38). A full-screen button with nothing
    /// deeper inside it is not a backdrop (a "tap anywhere to continue" screen), and neither is a full-screen image.
    var backdrop: UIEntry? {
        // Without the screen's bounds there is no telling a backdrop from a large element; sim-use 0.14 reports them.
        guard let bounds = screen else { return nil }
        let entries = entries ?? []
        return entries.first { entry in
            guard entry.role == "Button", let frame = entry.frame, frame.covers(bounds) else { return false }
            return entries.contains { other in
                guard other != entry, let inner = other.frame, !other.label.isEmpty, !other.isDisabled else { return false }
                return (other.depth ?? 0) > (entry.depth ?? 0) && frame.contains(inner)
            }
        }
    }
}

extension ElementFrame {
    /// Whether this frame spans `bounds`, give or take the point sim-use rounds frames by.
    func covers(_ bounds: Self) -> Bool {
        x <= bounds.x + 1 && y <= bounds.y + 1
            && x + width >= bounds.x + bounds.width - 1 && y + height >= bounds.y + bounds.height - 1
    }
}

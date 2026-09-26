extension UISnapshot {
    /// The first and last of the rows a list shows within reach: the largest group of two or more elements that line
    /// up (same role, left edge, and width), top to bottom. A row under a bar is left out, so the fingers never touch
    /// down or lift on a bar button. `nil` when nothing lines up.
    var rowRun: (first: ElementFrame, last: ElementFrame)? {
        let frames = (entries ?? [])
            .filter { !$0.isDisabled && revealingScroll(for: $0) == nil }
            .compactMap { entry in entry.frame.map { (entry.role, $0) } }
        let groups = Dictionary(grouping: frames) { "\($0.0)|\($0.1.x)|\($0.1.width)" }.values
            .map { $0.map(\.1).sorted { $0.y < $1.y } }
            .filter { $0.count >= 2 }
        guard let rows = groups.max(by: { $0.count < $1.count }), let first = rows.first, let last = rows.last else {
            return nil
        }
        return (first, last)
    }
}

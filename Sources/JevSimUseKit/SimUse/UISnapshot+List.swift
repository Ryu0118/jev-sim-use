extension UISnapshot {
    /// A pull to refresh down the middle of the screen, from 30% of its height to 85%: below a navigation bar, on the
    /// list, and about half the screen long. `nil` when the reading has no size.
    var refreshPull: SimUseDeviceAction? {
        let frames = (entries ?? []).compactMap(\.frame)
        let width = screen?.width ?? frames.map { $0.x + $0.width }.max() ?? 0
        let height = screen?.height ?? frames.map { $0.y + $0.height }.max() ?? 0
        guard width > 0, height > 0 else { return nil }
        return .pullToRefresh(x: (width / 2).rounded(), from: (height * 0.3).rounded(), to: (height * 0.85).rounded())
    }

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

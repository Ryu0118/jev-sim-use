extension UISnapshot {
    /// Roles of rows that open something when tapped.
    private static let navigableRowRoles: Set = ["Button", "Cell"]

    /// Whether the screen shows a list of rows to open: four or more buttons or cells spanning most of the screen's
    /// width. Rows of text do not count: a premium sheet listing features as text, and scanning it
    /// scrolled twice before Jev closed the sheet.
    var looksLikeNavigationList: Bool {
        let entries = entries ?? []
        let width = entries.compactMap(\.frame).map { $0.x + $0.width }.max() ?? 0
        return entries.count { entry in
            guard let frame = entry.frame, Self.navigableRowRoles.contains(entry.role) else { return false }
            return frame.width >= width * 0.8 && frame.height <= 100
        } >= 4
    }

    /// The first and last of the rows a list shows: the largest group of two or more elements that line up (same
    /// role, left edge, and width), top to bottom. `nil` when nothing lines up.
    var rowRun: (first: ElementFrame, last: ElementFrame)? {
        let frames = (entries ?? []).filter { !$0.isDisabled }.compactMap { entry in entry.frame.map { (entry.role, $0) } }
        let groups = Dictionary(grouping: frames) { "\($0.0)|\($0.1.x)|\($0.1.width)" }.values
            .map { $0.map(\.1).sorted { $0.y < $1.y } }
            .filter { $0.count >= 2 }
        guard let rows = groups.max(by: { $0.count < $1.count }), let first = rows.first, let last = rows.last else {
            return nil
        }
        return (first, last)
    }
}

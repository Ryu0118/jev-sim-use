extension UISnapshot {
    /// Roles of rows that open something when tapped.
    private static let navigableRowRoles: Set = ["Button", "Cell"]

    /// Whether the screen shows a list of rows to open: four or more buttons or cells spanning most of the screen's
    /// width. Rows of text do not count: DriveTracker's premium sheet lists its features as text, and scanning it
    /// scrolled twice before Jev closed the sheet.
    var looksLikeNavigationList: Bool {
        let entries = entries ?? []
        let width = entries.compactMap(\.frame).map { $0.x + $0.width }.max() ?? 0
        return entries.count { entry in
            guard let frame = entry.frame, Self.navigableRowRoles.contains(entry.role) else { return false }
            return frame.width >= width * 0.8 && frame.height <= 100
        } >= 4
    }
}

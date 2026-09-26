extension UISnapshot {
    /// The trait iOS gives the system status bar's items: the time, signal, Wi-Fi, battery, and the Dynamic Island.
    static let statusBarTrait = "StatusBarElement"

    /// `entries` without the system status bar's items, which the raw tree marks with `statusBarTrait`.
    ///
    /// sim-use lists them in the top band with the app's own bar, as `GenericElement` / `StaticText`. They are not the
    /// app's: after a sheet closed, Jev tapped the clock at 0.60 instead of going back, and the run stalled. The clock
    /// also changes the screen's identity every minute, so a tap repeated on an unchanged screen looked like progress
    /// on slow steps. Entries are matched to raw nodes by frame and label, as hints are; the Wi-Fi node has no label.
    static func withoutStatusBar(_ entries: [UIEntry], from raw: [RawAccessibilityNode]) -> [UIEntry] {
        let statusBar = raw.flatMap(\.flattened).filter { $0.traits?.contains(statusBarTrait) == true }
        guard !statusBar.isEmpty else { return entries }
        return entries.filter { entry in
            guard let frame = entry.frame else { return true }
            return !statusBar.contains { node in
                guard let nodeFrame = node.frame else { return false }
                return nodeFrame.isClose(to: frame) && [nil, entry.label].contains(node.label)
            }
        }
    }
}

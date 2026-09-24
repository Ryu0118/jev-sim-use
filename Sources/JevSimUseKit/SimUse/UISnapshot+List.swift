extension UISnapshot {
    /// Whether the screen shows a list: four or more rows spanning most of the screen's width.
    var looksLikeList: Bool {
        let frames = (entries ?? []).compactMap(\.frame)
        let width = frames.map { $0.x + $0.width }.max() ?? 0
        return frames.count(where: { $0.width >= width * 0.8 && $0.height <= 100 }) >= 4
    }
}

extension UISnapshot {
    /// A point inside `entry` that no overlay covers, when its centre is covered; `nil` when the centre is clear.
    ///
    /// sim-use taps an element's centre. A row scrolled under iOS's floating search bar had its centre inside the
    /// bar, so the tap opened search instead of the row. Elements that contain the whole target (the screen-sized
    /// group) or are its children (inside it and deeper in the tree, like a row's own label) do not count as
    /// overlays; the search bar lay inside the row's frame but shallower in the tree.
    func uncoveredPoint(of entry: UIEntry) -> (x: Double, y: Double)? {
        guard let target = entry.frame else { return nil }
        let center = target.center
        let overlays = (entries ?? []).filter { other in
            guard let frame = other.frame, frame != target, !frame.contains(target) else { return false }
            let isChild = target.contains(frame) && (other.depth ?? 0) > (entry.depth ?? 0)
            return !isChild
        }.compactMap(\.frame).filter { other in
            other.x <= center.x && center.x <= other.x + other.width
                && other.y < target.y + target.height && target.y < other.y + other.height
        }
        guard overlays.contains(where: { $0.y <= center.y && center.y <= $0.y + $0.height }) else { return nil }
        // Walk the target's vertical extent and keep the longest stretch no overlay covers.
        var covered = overlays.map { (max($0.y, target.y), min($0.y + $0.height, target.y + target.height)) }
            .sorted { $0.0 < $1.0 }
        covered.append((target.y + target.height, target.y + target.height))
        var best: (start: Double, length: Double) = (target.y, 0)
        var cursor = target.y
        for (start, end) in covered {
            if start - cursor > best.length {
                best = (cursor, start - cursor)
            }
            cursor = max(cursor, end)
        }
        return best.length > 0 ? (x: center.x, y: best.start + best.length / 2) : nil
    }
}

extension ElementFrame {
    /// Whether `other` lies entirely inside this frame.
    func contains(_ other: ElementFrame) -> Bool {
        x <= other.x && y <= other.y && other.x + other.width <= x + width && other.y + other.height <= y + height
    }
}

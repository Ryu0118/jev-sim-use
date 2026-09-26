extension UISnapshot {
    /// `entries` with the attributes of the raw node at the same place: iOS sim-use leaves them out of its entries.
    ///
    /// A cell's unlabelled container can share the frame of the control it wraps, so a node carrying the entry's own
    /// label wins over one without a label.
    static func withRawAttributes(_ entries: [UIEntry], from raw: [RawAccessibilityNode]) -> [UIEntry] {
        let nodes = raw.flatMap(\.flattened).filter { $0.frame != nil }
        return entries.map { entry in
            guard entry.traits == nil, let frame = entry.frame else { return entry }
            let placed = nodes.filter { $0.frame?.isClose(to: frame) == true }
            guard let node = placed.first(where: { $0.label == entry.label }) ?? placed.first(where: { $0.label == nil })
            else { return entry }
            var copy = entry
            copy.traits = node.traits
            return copy
        }
    }
}

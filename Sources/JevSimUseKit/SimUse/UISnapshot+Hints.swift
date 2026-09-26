/// One node of sim-use's raw accessibility tree, read only for what the entries leave out.
struct RawAccessibilityNode: Decodable {
    let label: String?
    let help: String?
    let frame: ElementFrame?
    /// iOS accessibility traits, such as `Button` or `StatusBarElement`.
    let traits: [String]?
    /// Names of the actions an element offers besides activation, such as deleting a row.
    let customActions: [String]?
    let children: [Self]?

    private enum CodingKeys: String, CodingKey {
        case label = "AXLabel"
        case customActions = "custom_actions"
        case help, frame, traits, children
    }

    /// This node and every node below it.
    var flattened: [Self] {
        [self] + (children ?? []).flatMap(\.flattened)
    }
}

extension UISnapshot {
    /// A hint shared by this many elements (the status bar's gesture help) tells Jev nothing about any one of them.
    static let sharedHintLimit = 3

    /// `entries` with the accessibility hint of the raw node at the same place and with the same label.
    ///
    /// iOS sim-use leaves `hint` empty in its entries, but the raw tree keeps it as `help`. An app can say there what a
    /// control does (an AI rewrite versus editing by hand), which its label alone may not.
    static func withHints(_ entries: [UIEntry], from raw: [RawAccessibilityNode]) -> [UIEntry] {
        let helped = raw.flatMap(\.flattened).filter { !($0.help ?? "").isEmpty && $0.frame != nil }
        var hinted = entries.map { entry -> UIEntry in
            guard entry.hint == nil, let frame = entry.frame else { return entry }
            let node = helped.first { node in
                guard let nodeFrame = node.frame else { return false }
                return nodeFrame.isClose(to: frame) && [nil, entry.label].contains(node.label)
            }
            var copy = entry
            copy.hint = node?.help
            return copy
        }
        let counts = Dictionary(grouping: hinted.compactMap(\.hint), by: { $0 }).mapValues(\.count)
        for index in hinted.indices where (counts[hinted[index].hint ?? ""] ?? 0) >= sharedHintLimit {
            hinted[index].hint = nil
        }
        return hinted
    }
}

extension ElementFrame {
    /// Whether two readings of a rectangle are the same one: sim-use rounds entries' frames, not raw ones.
    func isClose(to other: Self) -> Bool {
        abs(x - other.x) <= 1 && abs(y - other.y) <= 1 && abs(width - other.width) <= 1 && abs(height - other.height) <= 1
    }
}

extension UISnapshot {
    /// What makes two readings the same screen: the elements and their state, without frames or screen bands.
    ///
    /// A scroll that bounces at the end of a list moves every frame, and can move an element into another band, yet
    /// shows the same elements. Without `entries` (physical iOS devices) the text outline is all there is.
    var identity: String {
        guard let entries, !entries.isEmpty else { return outline }
        let elements = entries.map { entry in
            [entry.role, entry.label, entry.value ?? "", entry.uniqueId ?? "", entry.states.joined(separator: ",")]
                .joined(separator: "|")
        }
        return ([appLabel ?? ""] + elements).joined(separator: "\n")
    }
}

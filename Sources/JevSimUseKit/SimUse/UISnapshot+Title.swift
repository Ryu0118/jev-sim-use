extension UISnapshot {
    /// The navigation title: a collapsed title sits in the top bar; a large title is the first heading of the content.
    var title: String? {
        let headings = (entries ?? []).filter { $0.role == "Heading" && !$0.label.isEmpty }
        return (headings.first { $0.region?.kind == "Top" } ?? headings.first)?.label
    }
}

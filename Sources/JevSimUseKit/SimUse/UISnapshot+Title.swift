extension UISnapshot {
    /// The navigation title: a collapsed title sits in the top bar; a large title is the first heading of the content,
    /// with nothing of the content above it.
    ///
    /// A heading below other content is a section heading, not the title: a new-event sheet, whose top bar names it
    /// only in an unlabelled group's identifier, sent its "Location" section as the screen's title, and Jev, told the
    /// goal was in that sheet, answered BLOCKED. The top bar's identifier is not used instead: on a SwiftUI screen it
    /// is a class name. No title is sent rather than a wrong one.
    var title: String? {
        let entries = entries ?? []
        let headings = entries.filter { $0.role == "Heading" && !$0.label.isEmpty }
        if let collapsed = headings.first(where: { $0.region?.kind == "Top" }) {
            return collapsed.label
        }
        guard let first = headings.first else { return nil }
        guard let top = first.frame?.y, first.region?.kind == "Content" else { return first.label }
        let contentAbove = entries.contains { entry in
            guard entry != first, entry.region?.kind == "Content", let frame = entry.frame else { return false }
            return frame.y + frame.height <= top
        }
        return contentAbove ? nil : first.label
    }
}

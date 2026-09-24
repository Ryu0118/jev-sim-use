/// What `session` does, other than resuming (which `RunGoalRunner` handles).
package enum SessionOperation: Sendable, Equatable {
    /// All sessions, most recent first.
    case list
    /// One session; `nil` means the most recent.
    case show(id: String?)
    /// Adds a fact about the app that Jev will see on the next `resume`; `nil` means the most recent session.
    case tell(id: String?, note: String)
    /// Removes note `number` (1-based, as `show` numbers them), for a note that turned out wrong.
    case forget(id: String?, number: Int)
}

/// The result of a `SessionOperation`.
package enum SessionOutcome: Sendable, Equatable {
    /// The sessions `list` found.
    case sessions([SessionRecord])
    /// The session `show` read or `tell` changed.
    case session(SessionRecord)
}

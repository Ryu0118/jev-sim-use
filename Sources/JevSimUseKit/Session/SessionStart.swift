/// Which session a run works in.
package enum SessionStart: Sendable, Equatable {
    /// A new session for `goal`, with texts the agent may paste.
    case new(goal: String, texts: [String])
    /// An existing session; `nil` means the most recently updated one.
    case resume(id: String?)

    /// Whether this continues an existing session.
    package var isResume: Bool {
        if case .resume = self {
            true
        } else {
            false
        }
    }
}

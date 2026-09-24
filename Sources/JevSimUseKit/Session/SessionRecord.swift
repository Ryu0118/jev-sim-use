import Foundation

/// One goal pursued across `run` and `session resume`, with what a supervisor told the agent along the way.
package struct SessionRecord: Codable, Sendable, Hashable {
    /// Short identifier used on the command line.
    package let id: String
    /// The goal in natural language.
    package let goal: String
    /// Texts the agent may paste.
    package let texts: [InputText]
    /// The device the session drives, set once connected; resuming pins it again.
    package var deviceID: String?
    /// Facts about the app a supervisor added with `session tell`, oldest first.
    package var notes: [String] = []
    /// Every action taken so far, across runs.
    package var history: [HistoryEntry] = []
    /// How each run ended, oldest first.
    package var runs: [SessionRun] = []
    /// When the session last changed: the most recent session has the largest value, and expiry counts from it.
    package var updatedAt: Date

    package init(id: String, goal: String, texts: [InputText], deviceID: String? = nil, updatedAt: Date) {
        self.id = id
        self.goal = goal
        self.texts = texts
        self.deviceID = deviceID
        self.updatedAt = updatedAt
    }
}

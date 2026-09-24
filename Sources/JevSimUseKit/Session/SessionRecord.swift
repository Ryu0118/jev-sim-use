import Foundation

/// One goal pursued across `run` and `session resume`, with what a supervisor told the agent along the way.
package struct SessionRecord: Codable, Sendable, Hashable {
    /// Short identifier used on the command line.
    package let id: String
    /// The goal in natural language.
    package let goal: String
    /// Texts the agent may paste.
    package let texts: [String]
    /// The device the session drives, set once connected; resuming pins it again.
    package var deviceID: String?
    /// Facts about the app a supervisor added with `session tell`, oldest first.
    package var notes: [String] = []
    /// Every action taken so far, across runs.
    package var history: [HistoryEntry] = []
    /// How each run ended, oldest first.
    package var runs: [SessionRun] = []
    /// When the session was created.
    package let createdAt: Date
    /// When the session last changed; `latest` means the largest value.
    package var updatedAt: Date

    package init(id: String, goal: String, texts: [String], deviceID: String? = nil, createdAt: Date) {
        self.id = id
        self.goal = goal
        self.texts = texts
        self.deviceID = deviceID
        self.createdAt = createdAt
        updatedAt = createdAt
    }
}

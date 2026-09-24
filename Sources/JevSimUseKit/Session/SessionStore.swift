import FileManagerProtocol
import Foundation

/// Keeps one JSON file per session in `$XDG_STATE_HOME/jev-sim-use/sessions` (default `~/.local/state`).
///
/// Sessions exist to be resumed: a finished one is deleted, and an unfinished one expires `timeToLive` after its last
/// change.
package struct SessionStore: Sendable {
    /// How long an unfinished session is kept after it last changed: one week.
    package static let timeToLive: TimeInterval = 7 * 24 * 60 * 60

    /// The directory holding `<id>.json` files.
    let directory: URL
    private let fileManager: any FileManagerProtocol
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates a store under the state directory `environment` points at.
    package init(environment: [String: String], fileManager: some FileManagerProtocolMacOS = FileManager.default) {
        directory = UserDirectories(environment: environment, fileManager: fileManager).state
            .appending(path: "jev-sim-use/sessions")
        self.fileManager = fileManager
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    /// Writes `session`, replacing any earlier version.
    package func save(_ session: SessionRecord) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = fileURL(for: session.id)
        guard try fileManager.createFile(atPath: file.path(percentEncoded: false), contents: encoder.encode(session))
        else { throw SessionStoreError.writeFailed(file) }
    }

    /// The session with `id`, or the most recently updated one when `id` is `nil`.
    package func load(_ id: String?) throws -> SessionRecord {
        guard let id else {
            guard let latest = try list().first else { throw SessionStoreError.empty }
            return latest
        }
        guard let data = fileManager.contents(atPath: fileURL(for: id).path(percentEncoded: false)) else {
            throw SessionStoreError.notFound(id: id)
        }
        return try decoder.decode(SessionRecord.self, from: data)
    }

    /// All sessions, most recently updated first.
    package func list() throws -> [SessionRecord] {
        let path = directory.path(percentEncoded: false)
        guard fileManager.fileExists(atPath: path) else { return [] }
        return try fileManager.contentsOfDirectory(atPath: path)
            .filter { $0.hasSuffix(".json") }
            .compactMap { fileManager.contents(atPath: directory.appending(path: $0).path(percentEncoded: false)) }
            .map { try decoder.decode(SessionRecord.self, from: $0) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Deletes the session with `id`, if it exists.
    package func delete(_ id: String) throws {
        let path = fileURL(for: id).path(percentEncoded: false)
        guard fileManager.fileExists(atPath: path) else { return }
        try fileManager.removeItem(atPath: path)
    }

    /// Deletes sessions that last changed more than `timeToLive` before `now`.
    package func removeExpired(now: Date) throws {
        for session in try list() where now.timeIntervalSince(session.updatedAt) > Self.timeToLive {
            try delete(session.id)
        }
    }

    private func fileURL(for id: String) -> URL {
        directory.appending(path: "\(id).json")
    }
}

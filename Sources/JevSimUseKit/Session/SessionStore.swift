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

    /// Writes `session`, replacing any earlier version. Only the user can read sessions: they hold the goal, notes,
    /// and every `--text` value.
    package func save(_ session: SessionRecord) throws {
        let file = try fileURL(for: session.id)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path(percentEncoded: false))
        guard try fileManager.createFile(
            atPath: file.path(percentEncoded: false), contents: encoder.encode(session), attributes: [.posixPermissions: 0o600],
        ) else { throw SessionStoreError.writeFailed(file) }
    }

    /// The session with `id`, or the most recently updated one when `id` is `nil`.
    package func load(_ id: String?) throws -> SessionRecord {
        guard let id else {
            guard let latest = try list().first else { throw SessionStoreError.empty }
            return latest
        }
        guard let data = try fileManager.contents(atPath: fileURL(for: id).path(percentEncoded: false)) else {
            throw SessionStoreError.notFound(id: id)
        }
        return try decoder.decode(SessionRecord.self, from: data)
    }

    /// All readable sessions, most recently updated first.
    package func list() throws -> [SessionRecord] {
        try files().compactMap(\.session).sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Deletes the session with `id`, if it exists.
    package func delete(_ id: String) throws {
        let path = try fileURL(for: id).path(percentEncoded: false)
        guard fileManager.fileExists(atPath: path) else { return }
        try fileManager.removeItem(atPath: path)
    }

    /// Deletes sessions that last changed more than `timeToLive` before `now`, and files that no longer decode.
    package func removeExpired(now: Date) throws {
        for file in try files() where file.session.map({ now.timeIntervalSince($0.updatedAt) > Self.timeToLive }) ?? true {
            try delete(file.id)
        }
    }

    /// Ids come from the command line and from decoded files, so anything that could leave the directory (`/`, `..`)
    /// is refused rather than resolved.
    static func isValidID(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 64 && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }

    /// Every session file with its decoded contents. A file that does not decode (truncated, or written by an
    /// incompatible version) has `nil`, so one bad file cannot block every other session and every run.
    private func files() throws -> [(id: String, session: SessionRecord?)] {
        let path = directory.path(percentEncoded: false)
        guard fileManager.fileExists(atPath: path) else { return [] }
        return try fileManager.contentsOfDirectory(atPath: path)
            .filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(".json".count)) }
            .filter(Self.isValidID)
            .map { id in
                let data = fileManager.contents(atPath: directory.appending(path: "\(id).json").path(percentEncoded: false))
                return (id, data.flatMap { try? decoder.decode(SessionRecord.self, from: $0) })
            }
    }

    private func fileURL(for id: String) throws -> URL {
        guard Self.isValidID(id) else { throw SessionStoreError.notFound(id: id) }
        return directory.appending(path: "\(id).json")
    }
}

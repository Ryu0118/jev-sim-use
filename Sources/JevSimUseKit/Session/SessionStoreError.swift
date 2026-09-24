import Foundation

/// Why a session could not be read or written.
package enum SessionStoreError: Error, Equatable, Sendable, CustomStringConvertible {
    /// No session has this id.
    case notFound(id: String)
    /// No session exists yet.
    case empty
    /// `forget` named a note the session does not have.
    case noSuchNote(number: Int, count: Int)
    /// The session file could not be written.
    case writeFailed(URL)

    /// What went wrong and what to do.
    package var description: String {
        switch self {
        case let .notFound(id): "No session '\(id)'. Run `jev-sim-use session list` to see the ids."
        case .empty: "No sessions yet. Start one with `jev-sim-use \"<goal>\"`."
        case let .noSuchNote(number, count):
            "No note \(number): the session has \(count). Run `jev-sim-use session show` to see them numbered."
        case let .writeFailed(url): "Could not write \(url.path(percentEncoded: false))."
        }
    }
}

import Foundation

/// Failures writing the user config file.
package enum UserConfigStoreError: Error, Equatable, Sendable, CustomStringConvertible {
    /// The file could not be created or replaced.
    case writeFailed(URL)

    /// A message naming the file that could not be written.
    package var description: String {
        switch self {
        case let .writeFailed(url): "Could not write the config file at \(url.path(percentEncoded: false))."
        }
    }
}

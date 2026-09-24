import Foundation

/// Failures while installing or removing the bundled skill.
package enum SkillError: Error, Equatable, Sendable, CustomStringConvertible {
    /// A skill already exists at the destination and `--force` was not given.
    case alreadyInstalled(URL)
    /// The skill file could not be written.
    case writeFailed(URL)

    /// A message suitable for the console.
    package var description: String {
        switch self {
        case let .alreadyInstalled(url):
            "A skill is already installed at \(url.path(percentEncoded: false)). Pass --force to overwrite it."
        case let .writeFailed(url):
            "Could not write \(url.path(percentEncoded: false))."
        }
    }
}

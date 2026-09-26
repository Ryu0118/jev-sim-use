import Foundation

/// Failures while installing, removing, or printing the bundled skill.
package enum SkillError: Error, Equatable, Sendable, CustomStringConvertible {
    /// A skill already exists at the destination and `--force` was not given.
    case alreadyInstalled(URL)
    /// The skill file could not be written.
    case writeFailed(URL)
    /// No bundled file has this path; `available` lists the paths that exist.
    case unknownFile(String, available: [String])

    /// A message suitable for the console.
    package var description: String {
        switch self {
        case let .alreadyInstalled(url):
            "A skill is already installed at \(url.path(percentEncoded: false)). Pass --force to overwrite it."
        case let .writeFailed(url):
            "Could not write \(url.path(percentEncoded: false))."
        case let .unknownFile(path, available):
            "No skill file \"\(path)\"; available: \(available.joined(separator: ", "))."
        }
    }
}

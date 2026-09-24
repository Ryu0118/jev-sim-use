import Foundation

/// The result of a `SkillOperation`.
package enum SkillOutcome: Sendable, Equatable {
    /// The skill was written to this directory.
    case installed(URL)
    /// The skill was removed from this directory.
    case uninstalled(URL)
    /// Nothing was installed at this directory.
    case notInstalled(URL)
    /// The skill's contents.
    case contents(String)
}

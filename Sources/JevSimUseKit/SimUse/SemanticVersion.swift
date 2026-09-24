/// A `major.minor.patch` version, parsed leniently from `sim-use --version`.
package struct SemanticVersion: Sendable, Hashable, Comparable, CustomStringConvertible {
    /// The major component.
    package let major: Int
    /// The minor component.
    package let minor: Int
    /// The patch component.
    package let patch: Int

    /// The version as `major.minor.patch`.
    package var description: String {
        "\(major).\(minor).\(patch)"
    }

    /// Creates a version from its components.
    package init(_ major: Int, _ minor: Int, _ patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Accepts `0.9.0`, `v0.14.0`, and dev builds such as `v0.13.0-5-gabc-dirty`
    /// by their numeric prefix. `nil` when no version is found.
    package init?(parsing text: String) {
        let pattern = /v?(\d+)\.(\d+)\.(\d+)/
        guard let match = text.firstMatch(of: pattern),
              let major = Int(match.1), let minor = Int(match.2), let patch = Int(match.3)
        else { return nil }
        self.init(major, minor, patch)
    }

    /// Compares major, then minor, then patch.
    package static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

/// The screen band or container sim-use grouped an element into.
package struct ElementRegion: Decodable, Sendable, Hashable {
    /// `Top`, `Content`, `Bottom`, `NavBar`, `TabBar`, `Toolbar`, `Scroll`, or `Group`.
    package let kind: String
    /// The container's label, for `Group` regions.
    package let label: String?
}

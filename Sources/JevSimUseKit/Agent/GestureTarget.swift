/// An element Jev may aim a gesture at. Unlike tap targets, content roles such as `Image` count: a map or a photo
/// is what gets pinched or swiped.
package struct GestureTarget: Sendable, Hashable {
    /// The element's alias.
    package let alias: Int
    /// Its accessibility role.
    package let role: String
    /// Its label, shortened; may be empty.
    package let label: String

    package init(alias: Int, role: String, label: String) {
        self.alias = alias
        self.role = role
        self.label = label
    }
}

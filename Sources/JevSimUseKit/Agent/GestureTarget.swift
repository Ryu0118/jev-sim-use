/// An element Jev may aim a gesture at. Unlike tap targets, content roles such as `Image` count: a map or a photo
/// is what gets pinched or swiped.
package struct GestureTarget: Sendable, Hashable {
    /// The element's alias.
    package var alias: Int
    /// Its accessibility role.
    package var role: String
    /// Its label, shortened; may be empty.
    package var label: String

    package init(alias: Int, role: String, label: String) {
        self.alias = alias
        self.role = role
        self.label = label
    }

    /// The gesture as an action on this element.
    func action(_ gesture: ElementGesture) -> AgentAction {
        .gesture(gesture, alias: alias, role: role, label: label)
    }
}

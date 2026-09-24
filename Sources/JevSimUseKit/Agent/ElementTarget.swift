/// An element Jev may act on: tap it, gesture on it, or type into it.
package struct ElementTarget: Sendable, Hashable {
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

    /// The element's id in the state, which is also its option name in target questions.
    var optionName: String {
        PlanningState.elementID(alias)
    }
}

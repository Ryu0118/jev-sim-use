/// One element of the describe-ui outline.
package struct UIEntry: Decodable, Sendable, Hashable {
    /// Short aliases such as `@3`.
    package let aliases: ElementAliases
    /// Accessibility role, such as `Button` or `Cell`.
    package let role: String
    /// Accessibility label; may be empty.
    package let label: String
    /// Flags such as `selected`, `disabled`, or `value="…"`.
    package let states: [String]
    /// Current value, when the element has one.
    package let value: String?
    /// The accessibility identifier (e.g. `BackButton`), which often names an element's purpose better than its label.
    package let uniqueId: String?
    /// Where on screen sim-use placed the element; absent in older fixtures.
    package let region: ElementRegion?
    /// The element's rectangle; absent in older fixtures.
    package var frame: ElementFrame?

    /// Roles sim-use gives on / off controls. They report `"1"` / `"0"` as their value.
    static let toggleRoles: Set = ["CheckBox", "Switch", "Toggle"]

    /// Whether the element is an on / off control.
    package var isToggle: Bool {
        Self.toggleRoles.contains(role)
    }

    /// Whether sim-use reported the element as disabled.
    package var isDisabled: Bool {
        states.contains("disabled")
    }
}

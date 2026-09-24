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

    /// Whether sim-use reported the element as disabled.
    package var isDisabled: Bool {
        states.contains("disabled")
    }
}

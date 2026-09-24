/// One element of the describe-ui outline.
public struct UIEntry: Decodable, Sendable, Hashable {
    /// Short aliases such as `@3`.
    public let aliases: ElementAliases
    /// Accessibility role, such as `Button` or `Cell`.
    public let role: String
    /// Accessibility label; may be empty.
    public let label: String
    /// Flags such as `selected`, `disabled`, or `value="…"`.
    public let states: [String]
    /// Current value, when the element has one.
    public let value: String?

    /// Whether sim-use reported the element as disabled.
    public var isDisabled: Bool {
        states.contains("disabled")
    }
}

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
    package let frame: ElementFrame?
    /// Nesting depth in the accessibility tree; deeper elements inside a frame are its children, shallower ones float
    /// over it.
    package var depth: Int?
    /// The accessibility hint: what activating the element does. sim-use fills it on Android; on iOS `UISnapshot`
    /// copies it from the raw tree's `help`.
    package var hint: String?
    /// iOS accessibility traits (such as `TabButton`), which name what an element is in any language. `UISnapshot`
    /// copies them from the raw tree; `nil` when no raw node matched, as on Android.
    package var traits: [String]?
    /// iOS custom actions (deleting or pinning a row), copied from the raw tree like `traits`.
    package var customActions: [String]?

    /// Roles sim-use gives on / off controls. They report `"1"` / `"0"` as their value.
    static let toggleRoles: Set = ["CheckBox", "Switch", "Toggle"]

    /// Whether the element is an on / off control: a toggle role, or on iOS the `Toggle` trait, which marks a switch
    /// whatever role sim-use derived for it.
    package var isToggle: Bool {
        Self.toggleRoles.contains(role) || traits?.contains("Toggle") == true
    }

    /// Whether the element is a tab bar item. A segmented control's segments share its subrole but not this trait.
    package var isTabButton: Bool {
        traits?.contains("TabButton") == true
    }

    /// Whether the element is a full-width row button that shows its setting's value, such as a SwiftUI ColorPicker.
    /// Its control (the colour well) sits at the trailing edge and ignores a tap on the row's label. A list item or
    /// card that shows a value offers custom actions (delete, favourite) and opens from anywhere, so it is not one.
    package var isValueRow: Bool {
        role == "Button" && !(value ?? "").isEmpty && (frame?.width ?? 0) >= 200 && (customActions ?? []).isEmpty
    }

    /// Whether sim-use reported the element as disabled.
    package var isDisabled: Bool {
        states.contains("disabled")
    }
}

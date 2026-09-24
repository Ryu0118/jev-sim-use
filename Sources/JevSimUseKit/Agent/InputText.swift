/// A string the agent may enter into a field, under a name that says what it is (`email`, `password`).
///
/// Jev sees only the name and matches it to a field's label; code enters the value. The value never goes to Jev, so
/// a password is not sent to the endpoint, and Jev never has to guess what a bare string is for.
package struct InputText: Codable, Sendable, Hashable {
    /// What the text is, as Jev sees it.
    package let name: String
    /// What gets entered.
    package let value: String

    package init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

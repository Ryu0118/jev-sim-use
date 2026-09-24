/// The aliases a describe-ui element can be tapped by.
public struct ElementAliases: Decodable, Sendable, Hashable {
    private enum CodingKeys: String, CodingKey {
        case alias = "at"
    }

    /// The `@N` alias, valid until the next UI change.
    public let alias: Int
}

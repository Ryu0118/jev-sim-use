/// Configuration problems found before any request is sent.
public enum JevSettingsError: Error, Sendable, Equatable, CustomStringConvertible {
    /// `TYPESAFE_API_KEY` is unset or blank.
    case missingAPIKey
    /// The endpoint does not parse as an absolute URL.
    case invalidEndpoint(String)
    /// The endpoint is not HTTPS and not loopback HTTP.
    case insecureEndpoint(String)

    /// A message that tells the user how to fix the configuration.
    public var description: String {
        switch self {
        case .missingAPIKey:
            "Set \(JevSettings.apiKeyVariable) to your TypeSafe API key (bring your own key)."
        case let .invalidEndpoint(raw):
            "The Jev endpoint '\(raw)' is not an absolute URL."
        case let .insecureEndpoint(raw):
            "The Jev endpoint '\(raw)' must use HTTPS (plain HTTP is allowed for localhost only)."
        }
    }
}

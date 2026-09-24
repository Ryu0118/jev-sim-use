/// Configuration problems found before any request is sent.
public enum JevSettingsError: Error, Sendable, Equatable, CustomStringConvertible {
    /// `TYPESAFE_API_KEY` is unset or blank.
    case missingAPIKey
    /// The base URL does not parse as an absolute URL.
    case invalidBaseURL(String)
    /// The base URL is not HTTPS and not loopback HTTP.
    case insecureBaseURL(String)

    /// A message that tells the user how to fix the configuration.
    public var description: String {
        switch self {
        case .missingAPIKey:
            "Set \(JevSettings.apiKeyVariable) to your API key (bring your own key)."
        case let .invalidBaseURL(raw):
            "The base URL '\(raw)' is not an absolute URL."
        case let .insecureBaseURL(raw):
            "The base URL '\(raw)' must use HTTPS (plain HTTP is allowed for localhost only)."
        }
    }
}

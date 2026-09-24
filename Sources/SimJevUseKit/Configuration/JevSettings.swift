import Foundation
import Jev

/// Where and how to reach Jev. Resolved with the precedence flag > environment > default.
public struct JevSettings: Sendable, Hashable {
    /// Environment variable holding the API key (bring your own key).
    public static let apiKeyVariable = "TYPESAFE_API_KEY"
    /// Environment variable overriding the endpoint, e.g. for a proxy or a local stub.
    public static let endpointVariable = "TYPESAFE_ENDPOINT"
    /// Environment variable overriding the model.
    public static let modelVariable = "TYPESAFE_MODEL"
    /// The model used when neither a flag nor the environment names one.
    public static let defaultModel = "jev-latest"

    /// The full evaluation URL, not a base URL: swift-jev posts to it as given.
    public let endpoint: URL
    /// The model name sent with every request.
    public let model: String
    let apiKey: String

    /// Builds a client. The key never leaves this struct other than through here.
    public func makeClient() -> JevClient {
        JevClient(apiKey: apiKey, model: model, endpoint: endpoint)
    }
}

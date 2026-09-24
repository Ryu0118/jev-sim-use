import Foundation
import Jev

/// Where and how to reach Jev.
///
/// The tool only speaks TypeSafe's wire format. Anything else (e.g. Workers AI) goes
/// behind a compatible proxy that `base-url` points at.
public struct JevSettings: Sendable, Hashable {
    /// Environment variable holding the API key (bring your own key). Never read from flags or files.
    public static let apiKeyVariable = "TYPESAFE_API_KEY"
    /// Environment variable overriding the base URL.
    public static let baseURLVariable = "TYPESAFE_BASE_URL"
    /// Environment variable overriding the model.
    public static let modelVariable = "TYPESAFE_MODEL"
    /// The base URL used when nothing else names one.
    public static let defaultBaseURL = URL(string: "https://api.typesafe.ai")!
    /// The model used when nothing else names one.
    public static let defaultModel = "jev-latest"

    /// The base URL requests go to, without the evaluation path.
    public let baseURL: URL
    /// The model name sent with every request.
    public let model: String
    /// Appended to the base URL, matching TypeSafe's API.
    static let evaluationPath = "v1/systemone"
    let apiKey: String

    /// The URL swift-jev posts to.
    public var endpoint: URL {
        baseURL.appending(path: Self.evaluationPath)
    }

    /// Builds a client. The key never leaves this struct other than through here.
    public func makeClient() -> JevClient {
        JevClient(apiKey: apiKey, model: model, endpoint: endpoint)
    }
}

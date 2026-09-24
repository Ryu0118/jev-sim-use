import Foundation
import Jev

/// Where and how to reach Jev.
///
/// The tool only speaks TypeSafe's wire format. Anything else (e.g. Workers AI) goes
/// behind a compatible proxy that `base-url` points at.
package struct JevSettings: Sendable, Hashable {
    /// Environment variable holding the API key (bring your own key). Never read from flags or files.
    package static let apiKeyVariable = "TYPESAFE_API_KEY"
    /// Environment variable overriding the base URL.
    package static let baseURLVariable = "TYPESAFE_BASE_URL"
    /// Environment variable overriding the model.
    package static let modelVariable = "TYPESAFE_MODEL"
    /// The base URL used when nothing else names one.
    package static let defaultBaseURL = URL(string: "https://api.typesafe.ai")!
    /// The model used when nothing else names one.
    /// Pinned rather than `jev-latest`: the alias moves on each release, and the action thresholds were tuned
    /// against this version. Move it deliberately, re-running the real-device runs.
    package static let defaultModel = "jev-1.13.0"

    /// The base URL requests go to, without the evaluation path.
    package let baseURL: URL
    /// The model name sent with every request.
    package let model: String
    /// Appended to the base URL, matching TypeSafe's API.
    static let evaluationPath = "v1/systemone"
    let apiKey: String

    /// The URL swift-jev posts to.
    package var endpoint: URL {
        baseURL.appending(path: Self.evaluationPath)
    }

    /// Builds a client. The key never leaves this struct other than through here.
    package func makeClient() -> JevClient {
        JevClient(apiKey: apiKey, model: model, endpoint: endpoint)
    }
}

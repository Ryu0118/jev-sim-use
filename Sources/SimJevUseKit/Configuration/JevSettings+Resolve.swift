import Foundation
import Jev

extension JevSettings {
    /// Resolves settings from command-line values and the environment.
    ///
    /// The key is read from the environment only; accepting it as a flag would leak
    /// it into shell history and process listings.
    public static func resolve(
        endpointFlag: String?,
        modelFlag: String?,
        environment: [String: String] = ProcessInfo.processInfo.environment,
    ) throws(JevSettingsError) -> JevSettings {
        let key = (environment[apiKeyVariable] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw .missingAPIKey }
        let endpoint = try resolveEndpoint(flag: endpointFlag, environment: environment)
        let model = nonEmpty(modelFlag) ?? nonEmpty(environment[modelVariable]) ?? defaultModel
        return JevSettings(endpoint: endpoint, model: model, apiKey: key)
    }

    /// HTTPS only, except plain HTTP on loopback for local testing; the same rule as the `jev` CLI.
    static func resolveEndpoint(
        flag: String?,
        environment: [String: String],
    ) throws(JevSettingsError) -> URL {
        guard let raw = nonEmpty(flag) ?? nonEmpty(environment[endpointVariable]) else { return .jevSystemOne }
        guard let url = URL(string: raw), let scheme = url.scheme?.lowercased(), let host = url.host()?.lowercased()
        else { throw .invalidEndpoint(raw) }
        let loopback: Set = ["localhost", "127.0.0.1", "::1", "[::1]"]
        guard scheme == "https" || (scheme == "http" && loopback.contains(host)) else {
            throw .insecureEndpoint(raw)
        }
        return url
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

import Foundation

package extension JevSettings {
    /// Resolves settings with the precedence flag > environment > config file > default.
    static func resolve(
        baseURLFlag: String?,
        modelFlag: String?,
        config: UserConfig,
        environment: [String: String] = ProcessInfo.processInfo.environment,
    ) throws(JevSettingsError) -> JevSettings {
        guard let key = environment[apiKeyVariable].flatMap(nonEmpty) else { throw .missingAPIKey }
        let rawBaseURL = nonEmpty(baseURLFlag) ?? environment[baseURLVariable].flatMap(nonEmpty) ?? config.baseURL
        let baseURL = try rawBaseURL.map(validateBaseURL) ?? defaultBaseURL
        let model = nonEmpty(modelFlag) ?? environment[modelVariable].flatMap(nonEmpty) ?? config.model ?? defaultModel
        return JevSettings(baseURL: baseURL, model: model, apiKey: key)
    }

    /// HTTPS only, except plain HTTP on loopback for local testing; the same rule as the `jev` CLI.
    static func validateBaseURL(_ raw: String) throws(JevSettingsError) -> URL {
        guard let url = URL(string: raw), let scheme = url.scheme?.lowercased(), let host = url.host()?.lowercased()
        else { throw .invalidBaseURL(raw) }
        let loopback: Set = ["localhost", "127.0.0.1", "::1", "[::1]"]
        guard scheme == "https" || (scheme == "http" && loopback.contains(host)) else {
            throw .insecureBaseURL(raw)
        }
        return url
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

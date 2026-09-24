/// Persistent settings kept in the user's config file. Never holds secrets.
package struct UserConfig: Codable, Sendable, Hashable {
    /// Keys accepted by `sim-jev-use config`.
    package enum Key: String, CaseIterable, Sendable {
        case baseURL = "base-url"
        case model
    }

    private enum CodingKeys: String, CodingKey {
        case baseURL = "base-url"
        case model
    }

    /// Jev base URL, validated when set.
    package var baseURL: String?
    /// Jev model name.
    package var model: String?

    /// Creates a config with the given values.
    package init(baseURL: String? = nil, model: String? = nil) {
        self.baseURL = baseURL
        self.model = model
    }

    /// The value stored for `key`.
    package subscript(key: Key) -> String? {
        get {
            switch key {
            case .baseURL: baseURL
            case .model: model
            }
        }
        set {
            switch key {
            case .baseURL: baseURL = newValue
            case .model: model = newValue
            }
        }
    }
}

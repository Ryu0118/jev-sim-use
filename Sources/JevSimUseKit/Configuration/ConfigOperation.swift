/// One `config` request.
package enum ConfigOperation: Sendable, Equatable {
    /// Read one stored value.
    case get(UserConfig.Key)
    /// Store a value; `base-url` is validated first.
    case set(UserConfig.Key, String)
    /// Remove a stored value.
    case unset(UserConfig.Key)
    /// Read every stored value.
    case list
}

/// What a `config` request produced.
package enum ConfigOutcome: Sendable, Equatable {
    /// The value for a `get`, or `nil` when it is not stored.
    case value(String?)
    /// Stored keys and values, in `UserConfig.Key` order.
    case entries([ConfigEntry])
    /// The file was updated.
    case updated
}

/// One stored setting.
package struct ConfigEntry: Sendable, Equatable {
    /// The setting's key.
    package let key: UserConfig.Key
    /// The stored value.
    package let value: String
}

/// Reads and changes the persistent user config.
package struct ConfigRunner: Sendable {
    private let store: UserConfigStore

    package init(store: UserConfigStore) {
        self.store = store
    }

    /// Performs `operation`. `base-url` goes through the same validation `JevSettings` applies at run time.
    package func run(_ operation: ConfigOperation) throws -> ConfigOutcome {
        switch operation {
        case let .get(key):
            return try .value(store.load()[key])
        case let .set(key, value):
            if key == .baseURL {
                _ = try JevSettings.validateBaseURL(value)
            }
            try update { $0[key] = value }
            return .updated
        case let .unset(key):
            try update { $0[key] = nil }
            return .updated
        case .list:
            let config = try store.load()
            return .entries(UserConfig.Key.allCases.compactMap { key in
                config[key].map { ConfigEntry(key: key, value: $0) }
            })
        }
    }

    private func update(_ change: (inout UserConfig) -> Void) throws {
        var config = try store.load()
        change(&config)
        try store.save(config)
    }
}

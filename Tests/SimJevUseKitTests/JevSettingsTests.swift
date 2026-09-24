import Foundation
@testable import SimJevUseKit
import Testing

struct JevSettingsTests {
    private let key = [JevSettings.apiKeyVariable: "sk-test"]

    private func resolve(
        flag: String? = nil,
        environment: [String: String] = [:],
        config: UserConfig = UserConfig(),
    ) throws -> JevSettings {
        try JevSettings.resolve(
            baseURLFlag: flag, modelFlag: nil, config: config, environment: key.merging(environment) { $1 },
        )
    }

    @Test("requires the API key from the environment")
    func missingKey() {
        #expect(throws: JevSettingsError.missingAPIKey) {
            try JevSettings.resolve(baseURLFlag: nil, modelFlag: nil, config: UserConfig(), environment: [:])
        }
    }

    @Test("appends the evaluation path to the default base URL")
    func defaults() throws {
        let settings = try resolve()
        #expect(settings.endpoint.absoluteString == "https://api.typesafe.ai/v1/systemone")
        #expect(settings.model == "jev-latest")
    }

    @Test("prefers flag, then environment, then config")
    func precedence() throws {
        let environment = [JevSettings.baseURLVariable: "https://env.example"]
        let config = UserConfig(baseURL: "https://config.example", model: "jev-config")
        #expect(try resolve(config: config).baseURL.host() == "config.example")
        #expect(try resolve(config: config).model == "jev-config")
        #expect(try resolve(environment: environment, config: config).baseURL.host() == "env.example")
        #expect(try resolve(flag: "https://flag.example", environment: environment, config: config).baseURL.host() == "flag.example")
    }

    @Test("allows plain HTTP only on loopback")
    func transportSecurity() throws {
        #expect(try resolve(flag: "http://127.0.0.1:8787").endpoint.absoluteString == "http://127.0.0.1:8787/v1/systemone")
        #expect(throws: JevSettingsError.insecureBaseURL("http://api.example")) {
            try JevSettings.validateBaseURL("http://api.example")
        }
        #expect(throws: JevSettingsError.invalidBaseURL("not a url")) {
            try JevSettings.validateBaseURL("not a url")
        }
    }
}

import Foundation
@testable import SimJevUseKit
import Testing

struct JevSettingsTests {
    private let key = [JevSettings.apiKeyVariable: "sk-test"]

    @Test("requires the API key from the environment")
    func missingKey() {
        #expect(throws: JevSettingsError.missingAPIKey) {
            try JevSettings.resolve(endpointFlag: nil, modelFlag: nil, environment: [JevSettings.apiKeyVariable: "  "])
        }
    }

    @Test("defaults to the TypeSafe endpoint and jev-latest")
    func defaults() throws {
        let settings = try JevSettings.resolve(endpointFlag: nil, modelFlag: nil, environment: key)
        #expect(settings.endpoint.absoluteString == "https://api.typesafe.ai/v1/systemone")
        #expect(settings.model == "jev-latest")
    }

    @Test("prefers the flag over the environment")
    func precedence() throws {
        let environment = key.merging([
            JevSettings.endpointVariable: "https://proxy.example/v1/systemone",
            JevSettings.modelVariable: "jev-env",
        ]) { $1 }
        let fromEnvironment = try JevSettings.resolve(endpointFlag: nil, modelFlag: nil, environment: environment)
        let fromFlag = try JevSettings.resolve(endpointFlag: "https://flag.example/jev", modelFlag: "jev-flag", environment: environment)
        #expect(fromEnvironment.endpoint.host() == "proxy.example")
        #expect(fromEnvironment.model == "jev-env")
        #expect(fromFlag.endpoint.host() == "flag.example")
        #expect(fromFlag.model == "jev-flag")
    }

    @Test("allows plain HTTP only on loopback")
    func transportSecurity() throws {
        _ = try JevSettings.resolve(endpointFlag: "http://localhost:8080/v1/systemone", modelFlag: nil, environment: key)
        #expect(throws: JevSettingsError.insecureEndpoint("http://api.example/v1")) {
            try JevSettings.resolve(endpointFlag: "http://api.example/v1", modelFlag: nil, environment: key)
        }
        #expect(throws: JevSettingsError.invalidEndpoint("not a url")) {
            try JevSettings.resolve(endpointFlag: "not a url", modelFlag: nil, environment: key)
        }
    }
}

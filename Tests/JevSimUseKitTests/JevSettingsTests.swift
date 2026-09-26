@testable import JevSimUseKit
import Testing

/// Where requests go. A missing key, a base URL from the config file, and an insecure base URL refused by `config set`
/// run end to end in scripts/e2e.sh; these are the precedence and URL rules in full.
@Suite("Jev settings resolve flag, then environment, then config file, then default, and refuse insecure URLs")
struct JevSettingsTests {
    private static let config = UserConfig(baseURL: "https://config.example", model: "jev-config")

    @Test("takes each setting from the first source that has it", arguments: [
        ("nothing set: the defaults and the evaluation path", String?.none, [String: String](), UserConfig(),
         "https://api.typesafe.ai/v1/systemone", "jev-1.13.0"),
        ("the config file", nil, [:], config, "https://config.example/v1/systemone", "jev-config"),
        ("the environment over the config file", nil,
         [JevSettings.baseURLVariable: "https://env.example", JevSettings.modelVariable: "jev-env"], config,
         "https://env.example/v1/systemone", "jev-env"),
        ("the flag over everything", "https://flag.example", [JevSettings.baseURLVariable: "https://env.example"], config,
         "https://flag.example/v1/systemone", "jev-config"),
        ("a blank environment value is ignored", nil, [JevSettings.baseURLVariable: " "], config,
         "https://config.example/v1/systemone", "jev-config"),
    ] as [(String, String?, [String: String], UserConfig, String, String)])
    func precedence(_: String, flag: String?, environment: [String: String], config: UserConfig, endpoint: String, model: String) throws {
        let settings = try JevSettings.resolve(
            baseURLFlag: flag, modelFlag: nil, config: config,
            environment: environment.merging([JevSettings.apiKeyVariable: "sk-test"]) { $1 },
        )
        #expect(settings.endpoint.absoluteString == endpoint)
        #expect(settings.model == model)
    }

    @Test("allows HTTPS anywhere and plain HTTP only on loopback", arguments: [
        ("https", "https://api.example", Result<String, JevSettingsError>.success("https://api.example")),
        ("http on 127.0.0.1", "http://127.0.0.1:8787", .success("http://127.0.0.1:8787")),
        ("http on localhost", "http://localhost:8787", .success("http://localhost:8787")),
        ("http elsewhere", "http://api.example", .failure(.insecureBaseURL("http://api.example"))),
        ("not a URL", "not a url", .failure(.invalidBaseURL("not a url"))),
    ] as [(String, String, Result<String, JevSettingsError>)])
    func baseURL(_: String, raw: String, expected: Result<String, JevSettingsError>) {
        let result = Result { () throws(JevSettingsError) in try JevSettings.validateBaseURL(raw).absoluteString }
        #expect(result == expected)
    }
}

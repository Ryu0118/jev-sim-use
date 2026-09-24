import Foundation
@testable import JevSimUseKit
import Testing

struct ConfigRunnerTests {
    private let runner = ConfigRunner(store: UserConfigStore(environment: [
        "XDG_CONFIG_HOME": FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).path(),
    ]))

    @Test("sets, lists, and unsets values in key order")
    func lifecycle() throws {
        #expect(try runner.run(.set(.model, "jev-x")) == .updated)
        #expect(try runner.run(.set(.baseURL, "https://proxy.example")) == .updated)
        #expect(try runner.run(.list) == .entries([
            ConfigEntry(key: .baseURL, value: "https://proxy.example"),
            ConfigEntry(key: .model, value: "jev-x"),
        ]))
        _ = try runner.run(.unset(.model))
        #expect(try runner.run(.get(.model)) == .value(nil))
    }

    @Test("rejects an insecure base URL before writing")
    func rejectsInsecureBaseURL() throws {
        #expect(throws: JevSettingsError.insecureBaseURL("http://example.com")) {
            try runner.run(.set(.baseURL, "http://example.com"))
        }
        #expect(try runner.run(.list) == .entries([]))
    }
}

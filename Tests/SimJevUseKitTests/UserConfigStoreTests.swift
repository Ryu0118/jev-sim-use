import Foundation
@testable import SimJevUseKit
import Testing

struct UserConfigStoreTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)

    @Test("stores config under XDG_CONFIG_HOME and reads it back")
    func roundTrip() throws {
        let store = UserConfigStore(environment: ["XDG_CONFIG_HOME": directory.path(percentEncoded: false)])
        #expect(try store.load() == UserConfig())
        try store.save(UserConfig(baseURL: "https://proxy.example", model: nil))
        #expect(try store.load().baseURL == "https://proxy.example")
        #expect(store.fileURL.path(percentEncoded: false).hasSuffix("sim-jev-use/config.json"))
    }
}

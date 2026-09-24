@testable import JevSimUseKit
import Testing

@Suite("XDG base directories fall back to HOME and ignore empty values")
struct UserDirectoriesTests {
    @Test("defaults config and state under HOME when XDG variables are unset or empty")
    func defaults() {
        let directories = UserDirectories(environment: ["HOME": "/Users/example", "XDG_STATE_HOME": ""])
        #expect(directories.config.path(percentEncoded: false) == "/Users/example/.config")
        #expect(directories.state.path(percentEncoded: false) == "/Users/example/.local/state")
    }

    @Test("XDG_STATE_HOME overrides the state directory")
    func stateOverride() {
        let directories = UserDirectories(environment: ["HOME": "/Users/example", "XDG_STATE_HOME": "/tmp/state"])
        #expect(directories.state.path(percentEncoded: false) == "/tmp/state")
    }
}

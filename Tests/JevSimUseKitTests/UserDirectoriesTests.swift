@testable import JevSimUseKit
import Testing

/// The one resolver for HOME and XDG_*; sessions and config under XDG directories run end to end in scripts/e2e.sh.
@Suite("XDG base directories fall back to HOME and ignore empty values")
struct UserDirectoriesTests {
    @Test("resolves config and state directories", arguments: [
        ("unset: under HOME", [String: String](), "/Users/example/.config", "/Users/example/.local/state"),
        ("empty: under HOME", ["XDG_CONFIG_HOME": "", "XDG_STATE_HOME": ""], "/Users/example/.config", "/Users/example/.local/state"),
        ("set: the variable", ["XDG_CONFIG_HOME": "/tmp/config", "XDG_STATE_HOME": "/tmp/state"], "/tmp/config", "/tmp/state"),
    ] as [(String, [String: String], String, String)])
    func directories(_: String, environment: [String: String], config: String, state: String) {
        let directories = UserDirectories(environment: environment.merging(["HOME": "/Users/example"]) { $1 })
        #expect(directories.config.path(percentEncoded: false) == config)
        #expect(directories.state.path(percentEncoded: false) == state)
    }
}

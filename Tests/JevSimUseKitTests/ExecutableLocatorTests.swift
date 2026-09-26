@testable import JevSimUseKit
import Testing

/// Finding sim-use on PATH without `/usr/bin/env`, so "not installed" is told apart from exit 127. A missing sim-use
/// runs end to end in scripts/e2e.sh.
@Suite("sim-use is found by searching PATH in order")
struct ExecutableLocatorTests {
    @Test("returns the first executable in PATH order, or nil", arguments: [
        ("two matches: the first wins", true, true, "first"),
        ("a missing directory before the match is skipped", false, true, "second"),
        ("no match", false, false, nil),
    ] as [(String, Bool, Bool, String?)])
    func locate(_: String, inFirst: Bool, inSecond: Bool, expected: String?) throws {
        let first = TemporaryPath(), second = TemporaryPath()
        let directories = try [
            inFirst ? first.withExecutable("sim-use") : "/missing",
            inSecond ? second.withExecutable("sim-use") : "/missing/bin",
        ]
        let found = ExecutableLocator(environment: ["PATH": directories.joined(separator: ":")]).locate("sim-use")
        let expectedPath = expected.map { ($0 == "first" ? directories[0] : directories[1]) + "/sim-use" }
        #expect(found?.path(percentEncoded: false) == expectedPath)
    }

    @Test("returns nil when PATH is unset")
    func noPath() {
        #expect(ExecutableLocator(environment: [:]).locate("sim-use") == nil)
    }
}

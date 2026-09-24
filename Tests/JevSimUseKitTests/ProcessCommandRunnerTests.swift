import Foundation
@testable import JevSimUseKit
import Testing

struct ProcessCommandRunnerTests {
    @Test("drains output larger than the pipe buffer without deadlocking")
    func largeOutput() async throws {
        let output = try await ProcessCommandRunner().run(
            URL(filePath: "/bin/sh"),
            arguments: ["-c", "head -c 300000 /dev/zero | tr '\\0' x; echo oops >&2; exit 3"],
        )
        #expect(output.exitCode == 3)
        #expect(output.stdout.count == 300_000)
        #expect(output.stderr == "oops\n")
    }

    @Test("returns soon after exit even when a grandchild keeps the pipes open")
    func grandchildHoldsPipes() async throws {
        let clock = ContinuousClock()
        let start = clock.now
        let output = try await ProcessCommandRunner().run(
            URL(filePath: "/bin/sh"),
            arguments: ["-c", "sleep 5 & echo done"],
        )
        #expect(clock.now - start < .seconds(3))
        #expect(output.stdout == Data("done\n".utf8))
    }
}

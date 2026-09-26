import Foundation
@testable import JevSimUseKit
import Testing

/// The child-process edges every sim-use call crosses. Passing SIM_USE_NO_DAEMON on top of the inherited environment
/// runs end to end in scripts/e2e.sh.
@Suite("Running a child process survives large output, lingering grandchildren, and signals")
struct SubprocessCommandRunnerTests {
    @Test("drains output larger than the pipe buffer without deadlocking")
    func largeOutput() async throws {
        let output = try await SubprocessCommandRunner().run(
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
        let output = try await SubprocessCommandRunner().run(
            URL(filePath: "/bin/sh"),
            arguments: ["-c", "sleep 5 & echo done"],
        )
        #expect(clock.now - start < .seconds(3))
        #expect(output.stdout == Data("done\n".utf8))
    }

    @Test("reports a signalled child as 128 plus the signal, like a shell")
    func signalledChild() async throws {
        let output = try await SubprocessCommandRunner().run(URL(filePath: "/bin/sh"), arguments: ["-c", "kill -TERM $$"])
        #expect(output.exitCode == 128 + SIGTERM)
    }
}

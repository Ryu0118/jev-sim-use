@testable import SimJevUseCLI
import Synchronization

/// Captures everything a command writes.
final class RecordingOutput: Sendable {
    private let lines = Mutex<(stdout: [String], stderr: [String])>(([], []))

    var standardOutput: [String] {
        lines.withLock { $0.stdout }
    }

    var standardError: [String] {
        lines.withLock { $0.stderr }
    }

    var output: CLIOutput {
        CLIOutput(
            standardOutput: { line in self.lines.withLock { $0.stdout.append(line) } },
            standardError: { line in self.lines.withLock { $0.stderr.append(line) } },
        )
    }
}

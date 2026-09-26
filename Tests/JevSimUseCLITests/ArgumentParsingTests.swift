@testable import JevSimUseCLI
import JevSimUseKit
import Testing

/// What reaches a command from the command line. Output and exit statuses are checked end to end (scripts/e2e.sh).
struct ArgumentParsingTests {
    @Test("routes arguments to the command they name, a bare goal to run, and a goal named like a command through run",
          arguments: [
              (["Open the details screen"], "run: Open the details screen"),
              (["run", "skill"], "run: skill"),
              (["skill", "print"], "skill print"),
              (["session", "resume"], "session resume"),
          ])
    func routing(arguments: [String], expected: String) throws {
        let command = try JevSimUseCommand.parseAsRoot(arguments)
        let routed = switch command {
        case let run as RunCommand: "run: \(run.goal)"
        case is SkillCommand.Print: "skill print"
        case is SessionCommand.Resume: "session resume"
        default: "\(type(of: command))"
        }
        #expect(routed == expected)
    }

    @Test("reads --actions groups around spaces, all groups without it, and -t values that contain =")
    func values() throws {
        #expect(try RunCommand.parse(["x", "--actions", "tap, scroll"]).agent.allowedOperations == [.tap, .scroll])
        #expect(try RunCommand.parse(["x"]).agent.allowedOperations == OperationGroup.all)
        let command = try RunCommand.parse(["Log in", "-t", "email=alice@example.com", "-t", "password=a=b"])
        #expect(command.texts == [
            InputText(name: "email", value: "alice@example.com"), InputText(name: "password", value: "a=b"),
        ])
    }

    /// Every way an argument can be wrong before a command runs; each exits 64 without touching sim-use or Jev.
    @Test("rejects each invalid argument before running", arguments: [
        ["run", "x", "--max-steps", "0"],
        ["run", "x", "--min-confidence", "2"],
        ["run", "x", "--min-confidence", "-0.1"],
        ["run", "x", "--actions", "tap,fly"],
        ["run", "x", "-t", "ramen"],
        ["run", "x", "-t", "=ramen"],
        ["run", "x", "-t", "q=a", "-t", "q=b"],
        ["session", "tell", "-n", " "],
        ["session", "forget", "-n", "0"],
        ["skill", "install"],
        ["skill", "install", "--client", "claude", "--dest", "/tmp/skills"],
        ["skill", "print", "nope.md"],
        ["config", "set", "base-url", "http://example.com"],
    ])
    func rejects(arguments: [String]) {
        #expect(throws: (any Error).self) { try JevSimUseCommand.parseAsRoot(arguments) }
    }
}

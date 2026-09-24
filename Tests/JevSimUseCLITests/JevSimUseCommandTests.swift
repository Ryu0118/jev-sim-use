@testable import JevSimUseCLI
import Testing

struct JevSimUseCommandTests {
    @Test("routes a bare goal to the run command")
    func defaultSubcommand() throws {
        let command = try JevSimUseCommand.parseAsRoot(["Open the Settings app"])
        #expect((command as? RunCommand)?.goal == "Open the Settings app")
    }

    @Test("`skill` routes to the skill subcommand, so a goal with that name needs `run`")
    func skillSubcommand() throws {
        #expect(try JevSimUseCommand.parseAsRoot(["skill", "print"]) is SkillCommand.Print)
        let command = try JevSimUseCommand.parseAsRoot(["run", "skill"])
        #expect((command as? RunCommand)?.goal == "skill")
    }
}

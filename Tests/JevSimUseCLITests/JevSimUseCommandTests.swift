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

    @Test("root help points AI agents at the skill")
    func rootHelpMentionsSkill() {
        let help = JevSimUseCommand.helpMessage(columns: 1000)
        #expect(help.contains("jev-sim-use skill print"))
        #expect(help.contains("jev-sim-use skill install --client claude|agents"))
    }
}

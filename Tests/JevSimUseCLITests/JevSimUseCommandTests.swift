@testable import JevSimUseCLI
import Testing

struct JevSimUseCommandTests {
    @Test("routes a bare goal to the run command")
    func defaultSubcommand() throws {
        let command = try JevSimUseCommand.parseAsRoot(["Open the Settings app"])
        #expect((command as? RunCommand)?.goal == "Open the Settings app")
    }
}

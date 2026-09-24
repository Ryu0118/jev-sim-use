@testable import SimJevUseCLI
import Testing

struct SimJevUseCommandTests {
    @Test("routes a bare goal to the run command")
    func defaultSubcommand() throws {
        let command = try SimJevUseCommand.parseAsRoot(["Open the Settings app"])
        #expect((command as? RunCommand)?.goal == "Open the Settings app")
    }
}

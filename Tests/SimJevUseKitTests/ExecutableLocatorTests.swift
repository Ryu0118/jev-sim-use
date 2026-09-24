import Foundation
@testable import SimJevUseKit
import Testing

struct ExecutableLocatorTests {
    @Test("returns the first executable in PATH order")
    func firstMatchWins() {
        let locator = ExecutableLocator(
            environment: ["PATH": "/missing:/opt/homebrew/bin:/usr/local/bin"],
            isExecutable: { ["/opt/homebrew/bin/sim-use", "/usr/local/bin/sim-use"].contains($0) },
        )
        #expect(locator.locate("sim-use")?.path(percentEncoded: false) == "/opt/homebrew/bin/sim-use")
    }

    @Test("returns nil when PATH is missing or has no match", arguments: [[:], ["PATH": "/usr/bin:/bin"]])
    func notFound(environment: [String: String]) {
        let locator = ExecutableLocator(environment: environment, isExecutable: { _ in false })
        #expect(locator.locate("sim-use") == nil)
    }
}

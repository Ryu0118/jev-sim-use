import Foundation
@testable import JevSimUseKit
import Testing

struct ExecutableLocatorTests {
    @Test("returns the first executable in PATH order")
    func firstMatchWins() throws {
        let first = try TemporaryPath().withExecutable("sim-use")
        let second = try TemporaryPath().withExecutable("sim-use")
        let locator = ExecutableLocator(environment: ["PATH": "/missing:\(first):\(second)"])
        #expect(locator.locate("sim-use")?.path(percentEncoded: false) == "\(first)/sim-use")
    }

    @Test("returns nil when PATH is missing or has no match", arguments: [[:], ["PATH": "/missing/bin"]])
    func notFound(environment: [String: String]) {
        #expect(ExecutableLocator(environment: environment).locate("sim-use") == nil)
    }
}

@testable import SimJevUseKit
import Testing

struct SimJevUseKitTests {
    @Test("returns the starter greeting")
    func greeting() {
        #expect(SimJevUseKit.greeting() == "Hello from SimJevUse")
    }
}

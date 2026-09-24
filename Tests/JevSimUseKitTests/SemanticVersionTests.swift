@testable import JevSimUseKit
import Testing

struct SemanticVersionTests {
    @Test("parses release, tagged, and dev-build version strings", arguments: [
        ("0.9.0", SemanticVersion(0, 9, 0)),
        ("v0.14.0\n", SemanticVersion(0, 14, 0)),
        ("v0.13.0-5-gabc123-dirty", SemanticVersion(0, 13, 0)),
    ])
    func parses(text: String, expected: SemanticVersion) {
        #expect(SemanticVersion(parsing: text) == expected)
    }

    @Test("rejects output without a version")
    func rejectsGarbage() {
        #expect(SemanticVersion(parsing: "sim-use: unknown") == nil)
    }

    @Test("orders numerically, not lexically")
    func ordering() {
        #expect(SemanticVersion(0, 9, 0) < SemanticVersion(0, 14, 0))
        #expect(SemanticVersion(1, 0, 0) > SemanticVersion(0, 99, 99))
    }
}

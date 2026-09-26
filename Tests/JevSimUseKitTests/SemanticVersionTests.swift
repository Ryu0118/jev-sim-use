@testable import JevSimUseKit
import Testing

/// Reading `sim-use --version`. A too-old and a newer-than-tested sim-use run end to end in scripts/e2e.sh; these are
/// the shapes the output takes.
@Suite("sim-use's version is read from any form of its version output and compared numerically")
struct SemanticVersionTests {
    @Test("parses release, tagged, and dev-build versions, and nothing else", arguments: [
        ("0.9.0", SemanticVersion?.some(SemanticVersion(0, 9, 0))),
        ("v0.14.0\n", SemanticVersion(0, 14, 0)),
        ("v0.13.0-5-gabc123-dirty", SemanticVersion(0, 13, 0)),
        ("sim-use: unknown", nil),
    ])
    func parses(text: String, expected: SemanticVersion?) {
        #expect(SemanticVersion(parsing: text) == expected)
    }

    @Test("orders numerically, not lexically")
    func ordering() {
        #expect(SemanticVersion(0, 9, 0) < SemanticVersion(0, 14, 0))
        #expect(SemanticVersion(1, 0, 0) > SemanticVersion(0, 99, 99))
    }
}

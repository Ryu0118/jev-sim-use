@testable import JevSimUseKit
import Testing

struct FailureCategoryTests {
    @Test("treats missing setup as fixable before running")
    func setup() {
        #expect(FailureCategory(JevSettingsError.missingAPIKey) == .setup)
        #expect(FailureCategory(SimUseError.noDevice) == .setup)
    }

    @Test("treats sim-use and Jev failures during a run as runtime")
    func runtime() {
        #expect(FailureCategory(SimUseError.malformedOutput(arguments: [], detail: "")) == .runtime)
        #expect(FailureCategory(PlanningError.missingChoice) == .runtime)
    }
}

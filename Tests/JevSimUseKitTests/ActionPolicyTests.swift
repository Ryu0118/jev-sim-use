@testable import JevSimUseKit
import Testing

struct ActionPolicyTests {
    @Test("uses the user's threshold for taps and caps it for harmless scrolls and back", arguments: [0.3, 0.6, 0.9])
    func reversible(minimum: Double) {
        let policy = ActionPolicy(minimumSupport: minimum)
        #expect(policy.requiredSupport(for: .device(.goBack)) == min(minimum, ActionPolicy.harmlessMaximum))
        #expect(policy.requiredSupport(for: .tap(alias: 1, role: "Button", label: "OK")) == minimum)
    }

    @Test("demands more before pasting text, which going back cannot undo")
    func irreversible() {
        let policy = ActionPolicy(minimumSupport: 0.3)
        #expect(policy.requiredSupport(for: .paste(index: 0, text: "hi")) == ActionPolicy.irreversibleMinimum)
    }

    @Test("demands more before leaving the app or locking the device", arguments: [
        AgentAction.device(.press(.home)), .device(.press(.lock)),
    ])
    func leavingTheApp(action: AgentAction) {
        #expect(ActionPolicy(minimumSupport: 0.3).requiredSupport(for: action) == ActionPolicy.irreversibleMinimum)
    }

    @Test("treats a sideways swipe as irreversible only on list rows, which it can delete", arguments: [
        ("Cell", ActionPolicy.irreversibleMinimum), ("Slider", 0.3), ("Image", 0.3),
    ])
    func sidewaysSwipe(role: String, required: Double) {
        let swipe = AgentAction.gesture(.swipeLeft, alias: 1, role: role, label: "x")
        #expect(ActionPolicy(minimumSupport: 0.3).requiredSupport(for: swipe) == required)
    }
}

@testable import JevSimUseKit
import Testing

struct ActionPolicyTests {
    @Test("uses the user's threshold for taps and caps it for harmless scrolls and back", arguments: [0.3, 0.6, 0.9])
    func reversible(minimum: Double) {
        let policy = ActionPolicy(minimumSupport: minimum)
        #expect(policy.requiredSupport(for: .device(.goBack)) == min(minimum, ActionPolicy.harmlessMaximum))
        #expect(policy.requiredSupport(for: .tap(alias: 1, role: "Button", label: "OK")) == minimum)
    }

    @Test("gates typing like a tap, since text in a field can be cleared and submits nothing", arguments: [0.3, 0.55])
    func typing(minimum: Double) {
        let policy = ActionPolicy(minimumSupport: minimum)
        #expect(policy.requiredSupport(for: .enterText(field: 1, label: "Name", text: InputText(name: "text", value: "hi"))) == minimum)
    }

    @Test("demands more before leaving the app or locking the device", arguments: [
        AgentAction.device(.press(.home)), .device(.press(.lock)),
    ])
    func leavingTheApp(action: AgentAction) {
        #expect(ActionPolicy(minimumSupport: 0.3).requiredSupport(for: action) == ActionPolicy.irreversibleMinimum)
    }

    @Test("treats tapping a destructive control as irreversible, and a short sideways swipe as reversible")
    func destructive() {
        let policy = ActionPolicy(minimumSupport: 0.3)
        #expect(policy.requiredSupport(for: .tap(alias: 1, role: "Button", label: "削除")) == ActionPolicy.irreversibleMinimum)
        #expect(policy.requiredSupport(for: .tap(alias: 1, role: "Button", label: "Delete List")) == ActionPolicy.irreversibleMinimum)
        #expect(policy.requiredSupport(for: .gesture(.swipeLeft, alias: 1, role: "Cell", label: "x")) == 0.3)
    }

    @Test("treats zooming and rotating like scrolling: they only change the view")
    func viewOnlyGestures() {
        let rotate = AgentAction.gesture(.rotateClockwise, alias: 1, role: "Image", label: "Map")
        #expect(ActionPolicy(minimumSupport: 0.6).requiredSupport(for: rotate) == ActionPolicy.harmlessMaximum)
    }
}

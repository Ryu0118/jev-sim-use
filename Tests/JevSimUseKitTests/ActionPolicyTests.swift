import Jev
@testable import JevSimUseKit
import Testing

struct ActionPolicyTests {
    @Test("uses the user's threshold for taps and caps it for harmless scrolls and back", arguments: [0.3, 0.6, 0.9])
    func reversible(minimum: Double) {
        let policy = ActionPolicy(minimumSupport: minimum)
        #expect(policy.requiredSupport(for: AgentAction.device(.goBack).risk) == min(minimum, ActionPolicy.harmlessMaximum))
        #expect(policy.requiredSupport(for: .reversible) == minimum)
    }

    @Test("gates typing like a tap, since text in a field can be cleared and submits nothing", arguments: [0.3, 0.55])
    func typing(minimum: Double) {
        let policy = ActionPolicy(minimumSupport: minimum)
        let enter = AgentAction.enterText(field: 1, label: "Name", text: InputText(name: "text", value: "hi"))
        #expect(policy.requiredSupport(for: enter.risk) == minimum)
    }

    @Test("demands more before leaving the app or locking the device", arguments: [
        AgentAction.device(.press(.home)), .device(.press(.lock)),
    ])
    func leavingTheApp(action: AgentAction) {
        #expect(ActionPolicy(minimumSupport: 0.3).requiredSupport(for: action.risk) == ActionPolicy.leavesAppMinimum)
    }

    @Test(
        "keeps a tap irreversible unless Jev clearly judged it undoable, since an unsure or missing answer is no proof",
        arguments: [(nil, ActionRisk.irreversible), (0.9, .irreversible), (0.5, .irreversible), (0.35, .irreversible), (0.1, .reversible)],
    )
    func tapRisk(irreversible: Double?, risk: ActionRisk) {
        let plan = StepPlan(
            action: .tap(alias: 1, role: "Button", label: "x"), confidence: 0.9,
            irreversible: irreversible.map { Probability(clamping: $0) }, costUSD: 0,
        )
        #expect(plan.risk == risk)
    }

    @Test("reads the irreversibility answer only for a tap; a short sideways swipe stays reversible")
    func gestureIgnoresTapAnswer() {
        let swipe = StepPlan(
            action: .gesture(.swipeLeft, alias: 1, role: "Cell", label: "x"), confidence: 0.9,
            irreversible: Probability(clamping: 0.9), costUSD: 0,
        )
        #expect(ActionPolicy(minimumSupport: 0.3).requiredSupport(for: swipe.risk) == 0.3)
        #expect(ActionPolicy(minimumSupport: 0.3).requiredSupport(for: .irreversible) == ActionPolicy.irreversibleMinimum)
    }

    @Test("treats zooming and rotating like scrolling: they only change the view")
    func viewOnlyGestures() {
        let rotate = AgentAction.gesture(.rotateClockwise, alias: 1, role: "Image", label: "Map")
        #expect(ActionPolicy(minimumSupport: 0.6).requiredSupport(for: rotate.risk) == ActionPolicy.harmlessMaximum)
    }
}

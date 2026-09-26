@testable import JevSimUseKit
import Testing

/// The bar each kind of action must clear. The loop's hand-over at the destructive bar runs end to end in
/// scripts/e2e.sh; this is the table itself, one row per risk.
@Suite("Each kind of action needs the support its risk warrants")
struct ActionPolicyTests {
    @Test("sets the required support by risk", arguments: [
        ("a tap uses the user's minimum", AgentAction.tap(alias: 1, role: "Button", label: "OK"), 0.9, 0.9),
        ("typing is gated like a tap: text is cleared as easily and submits nothing",
         .enterText(field: 1, label: "Name", text: InputText(name: "text", value: "hi")), 0.55, 0.55),
        ("going back is harmless, so a high minimum is capped", .device(.goBack), 0.9, ActionPolicy.harmlessMaximum),
        ("a low minimum still applies to harmless actions", .device(.goBack), 0.3, 0.3),
        ("rotating only changes the view", .gesture(.rotateClockwise, alias: 1, role: "Image", label: "Map"), 0.6,
         ActionPolicy.harmlessMaximum),
        ("a short sideways swipe only reveals a row's actions", .gesture(.swipeLeft, alias: 1, role: "Cell", label: "x"), 0.3, 0.3),
        ("a tap on a destructive control is irreversible", .tap(alias: 1, role: "Button", label: "削除"), 0.3,
         ActionPolicy.irreversibleMinimum),
        ("English destructive words count, inside longer labels too", .tap(alias: 1, role: "Button", label: "Delete List"), 0.3,
         ActionPolicy.irreversibleMinimum),
        ("pressing Home leaves the app, which sim-use cannot open again", .device(.press(.home)), 0.3,
         ActionPolicy.leavesAppMinimum),
        ("locking the device leaves the app too", .device(.press(.lock)), 0.3, ActionPolicy.leavesAppMinimum),
    ] as [(String, AgentAction, Double, Double)])
    func requiredSupport(_: String, action: AgentAction, minimum: Double, expected: Double) {
        #expect(ActionPolicy(minimumSupport: minimum).requiredSupport(for: action) == expected)
    }
}

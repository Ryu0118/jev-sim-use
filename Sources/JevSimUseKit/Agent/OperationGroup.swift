/// A family of operations the user can allow with `--actions`; `done` and `blocked` are always offered.
///
/// Leaving out operations a goal cannot need shrinks every request and removes wrong choices such as pressing the
/// Home button, which leaves the app.
package enum OperationGroup: String, Sendable, Hashable, CaseIterable {
    case tap
    case type
    case scroll
    case back
    case `return`
    case longPress = "long-press"
    case swipe
    case pinch
    case rotate
    case buttons

    /// Every group: the default when `--actions` is not given.
    package static let all = Set(allCases)

    /// Whether `operation` belongs to this group.
    func contains(_ operation: Operation) -> Bool {
        switch (self, operation) {
        case (.tap, .tap), (.type, .enterText): true
        case let (.longPress, .gesture(gesture)): gesture == .longPress
        case let (.swipe, .gesture(gesture)): [.swipeLeft, .swipeRight, .swipeUp, .swipeDown].contains(gesture)
        case let (.pinch, .gesture(gesture)): [.pinchIn, .pinchOut].contains(gesture)
        case let (.rotate, .gesture(gesture)): [.rotateClockwise, .rotateCounterclockwise].contains(gesture)
        case let (.scroll, .device(action)):
            [.revealContentBelow, .revealContentAbove, .revealContentRight, .revealContentLeft].contains(action)
        case let (.back, .device(action)): action == .goBack
        case let (.swipe, .device(action)): action == .swipeFromRightEdge
        case let (.return, .device(action)): action == .pressReturn
        case (.buttons, .device(.press)): true
        default: false
        }
    }
}

extension Set<OperationGroup> {
    /// Whether any allowed group contains `operation`; `done` and `blocked` always pass.
    func allows(_ operation: Operation) -> Bool {
        operation == .done || operation == .blocked || contains { $0.contains(operation) }
    }
}

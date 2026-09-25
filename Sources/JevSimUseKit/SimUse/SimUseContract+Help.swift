package extension SimUseContract {
    /// What each subcommand's `--help` must mention for this tool to work: the drift check behind the contract test.
    static let helpExpectations: [(command: String, mentions: [String])] = [
        (Command.ui, [noRawFlag, jsonFlag, deviceFlag]),
        (Command.devices, [jsonFlag, noPhysicalIOSFlag]),
        (Command.tap, [deviceFlag, jsonFlag, Tap.x, Tap.y, Tap.duration, Tap.id, Tap.label, "UISwitch"]),
        (Command.gesture, [
            Gesture.scrollUp, Gesture.scrollDown, Gesture.scrollLeft, Gesture.scrollRight,
            Gesture.swipeFromLeftEdge, Gesture.swipeFromRightEdge,
            Gesture.pinchIn, Gesture.pinchOut, Gesture.rotateClockwise, Gesture.rotateCounterclockwise,
            Gesture.centerX, Gesture.centerY, Gesture.duration, "device-native portrait", deviceFlag,
        ]),
        (Command.button, HardwareButton.allCases.map(\.rawValue) + [Button.back, deviceFlag]),
        (Command.paste, [deviceFlag, jsonFlag]),
        (Command.keyboardState, [deviceFlag, jsonFlag]),
        (Command.longPress, [deviceFlag, jsonFlag]),
        (Command.swipe, [Swipe.from, Swipe.to, deviceFlag, jsonFlag]),
        (Command.iosKey.joined(separator: " "), ["\(Key.returnKeycode) - Return", deviceFlag, jsonFlag]),
    ]
}

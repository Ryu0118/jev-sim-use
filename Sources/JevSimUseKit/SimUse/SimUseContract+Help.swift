package extension SimUseContract {
    /// What each subcommand's `--help` must mention for this tool to work: the drift check behind the contract test.
    static let helpExpectations: [(command: String, mentions: [String])] = [
        (Command.ui, [noRawFlag, jsonFlag, deviceFlag]),
        (Command.devices, [jsonFlag]),
        (Command.tap, [deviceFlag, jsonFlag, Tap.x, Tap.y, Tap.duration, "UISwitch"]),
        (Command.gesture, [
            Gesture.scrollUp, Gesture.scrollDown, Gesture.scrollLeft, Gesture.scrollRight,
            Gesture.swipeFromLeftEdge, Gesture.swipeFromRightEdge, Gesture.swipeFromTopEdge, Gesture.swipeFromBottomEdge,
            Gesture.pinchIn, Gesture.pinchOut, Gesture.rotateClockwise, Gesture.rotateCounterclockwise,
            Gesture.centerX, Gesture.centerY, Gesture.scale, Gesture.angle, "device-native portrait", deviceFlag,
        ]),
        (Command.button, [
            Button.home, Button.lock, Button.back, Button.recents, Button.applePay, Button.sideButton, Button.siri,
            deviceFlag,
        ]),
        (Command.paste, [deviceFlag, jsonFlag]),
        (Command.longPress, [deviceFlag, jsonFlag]),
        (Command.swipe, [Swipe.from, Swipe.to, deviceFlag, jsonFlag]),
    ]
}

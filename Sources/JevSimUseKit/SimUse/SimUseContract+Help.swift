package extension SimUseContract {
    /// What each subcommand's `--help` must mention for this tool to work: the drift check behind the contract test.
    static let helpExpectations: [(command: String, mentions: [String])] = [
        (Command.ui, [noRawFlag, jsonFlag, deviceFlag]),
        (Command.devices, [jsonFlag]),
        (Command.tap, [deviceFlag, jsonFlag, Tap.x, Tap.y, Tap.duration, "UISwitch"]),
        (Command.gesture, [Gesture.scrollUp, Gesture.scrollDown, Gesture.swipeFromLeftEdge, deviceFlag]),
        (Command.button, [Button.back, deviceFlag]),
        (Command.paste, [deviceFlag, jsonFlag]),
    ]
}

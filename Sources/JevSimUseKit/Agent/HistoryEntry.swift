/// One earlier step, as Jev sees it in `history`.
package struct HistoryEntry: Codable, Sendable, Hashable {
    /// 1-based step number.
    package let step: Int
    /// What was done, in words.
    package let action: String
    /// Whether the next observation differed from the screen the action ran on; `nil` until observed.
    package var screenChanged: Bool?
    /// Whether the action's effect can leave the screen as it was (a refresh); `nil` in sessions saved before it.
    package var effectMayNotShow: Bool?

    package init(step: Int, action: String, screenChanged: Bool?, effectMayNotShow: Bool? = nil) {
        self.step = step
        self.action = action
        self.screenChanged = screenChanged
        self.effectMayNotShow = effectMayNotShow
    }

    private enum CodingKeys: String, CodingKey {
        case step
        case action
        case screenChanged = "screen_changed"
        case effectMayNotShow = "effect_may_not_show"
    }
}

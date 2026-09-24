/// One earlier step, as Jev sees it in `history`.
package struct HistoryEntry: Encodable, Sendable, Hashable {
    /// 1-based step number.
    package let step: Int
    /// What was done, in words.
    package let action: String
    /// Whether the next observation differed from the screen the action ran on; `nil` until observed.
    package var screenChanged: Bool?

    private enum CodingKeys: String, CodingKey {
        case step
        case action
        case screenChanged = "screen_changed"
    }
}

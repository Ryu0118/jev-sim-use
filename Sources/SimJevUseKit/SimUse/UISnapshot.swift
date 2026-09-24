/// The `data` payload of `sim-use ui --json --no-raw`.
public struct UISnapshot: Decodable, Sendable, Hashable {
    /// Present only when sim-use detected an Android crash dialog.
    public struct CrashDialog: Decodable, Sendable, Hashable {
        /// The dialog title, when sim-use could read it.
        public let title: String?
    }

    /// `ios` or `android`.
    public let platform: String
    /// The compact text outline, identical to what text mode prints.
    public let outline: String
    /// Elements in reading order. Absent on physical iOS devices.
    public let entries: [UIEntry]?
    /// Set when an Android crash dialog is on screen.
    public let crashDialog: CrashDialog?
}

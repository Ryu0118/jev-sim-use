/// The `data` payload of `sim-use ui --json --no-raw`.
package struct UISnapshot: Decodable, Sendable, Hashable {
    /// Present only when sim-use detected an Android crash dialog.
    package struct CrashDialog: Decodable, Sendable, Hashable {
        /// The dialog title, when sim-use could read it.
        package let title: String?
    }

    /// `ios` or `android`.
    package let platform: String
    /// The compact text outline, identical to what text mode prints.
    package let outline: String
    /// The foreground app's name.
    package let appLabel: String?
    /// Elements in reading order. Absent on physical iOS devices.
    package let entries: [UIEntry]?
    /// Set when an Android crash dialog is on screen.
    package let crashDialog: CrashDialog?
}

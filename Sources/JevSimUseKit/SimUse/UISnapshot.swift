/// The `data` payload of `sim-use ui --json`.
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
    /// The screen's bounds in the same space as element frames, when sim-use reports them.
    package var screen: ElementFrame?
}

extension UISnapshot {
    private enum CodingKeys: String, CodingKey {
        case platform, outline, appLabel, entries, crashDialog, raw, screen
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entries = try container.decodeIfPresent([UIEntry].self, forKey: .entries)
        let raw = try container.decodeIfPresent([RawAccessibilityNode].self, forKey: .raw) ?? []
        try self.init(
            platform: container.decode(String.self, forKey: .platform),
            outline: container.decode(String.self, forKey: .outline),
            appLabel: container.decodeIfPresent(String.self, forKey: .appLabel),
            entries: entries.map { Self.withHints($0, from: raw) },
            crashDialog: container.decodeIfPresent(CrashDialog.self, forKey: .crashDialog),
            screen: container.decodeIfPresent(ElementFrame.self, forKey: .screen),
        )
    }
}

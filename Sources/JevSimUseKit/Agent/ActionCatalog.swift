/// Builds what Jev may choose from on one screen.
enum ActionCatalog {
    /// Jev accepts at most 255 options per choice question.
    static let maximumOptions = 255
    /// Labels are shortened in progress lines and history; the full text stays in the state.
    static let maximumLabelLength = 60
    /// The accessibility identifier of UIKit's navigation back button. Tapping it does what `go_back` does, and
    /// offering both split Jev's probability (the back button is labelled with the previous screen, such as 一般).
    static let iOSBackButtonIdentifier = "BackButton"
    /// Screen and section titles: tapping one does nothing, and offering them pulled Jev toward the current title.
    static let titleRoles: Set = ["Heading"]
    /// Roles of list rows, where a long sideways swipe can delete the row.
    static let rowRoles: Set = ["Cell", "Row"]
    /// Roles that accept typed text.
    static let editableRoles = ["TextField", "SearchField", "TextArea", "EditText"]

    /// The menu for `snapshot`, minus screen-level actions in `excluded` that already did nothing on this screen.
    ///
    /// Every enabled element but a title is a target: some apps expose tappable rows only as `StaticText`
    /// (Reminders), and a tap that does nothing is reported back through `history` rather than guessed away here.
    static func menu(for snapshot: UISnapshot, texts: [InputText], excluding excluded: Set<String> = []) -> ActionMenu {
        let entries = (snapshot.entries ?? []).filter { !$0.isDisabled }
        let elements = entries
            .filter { snapshot.platform != SimUseContract.Platform.ios || $0.uniqueId != iOSBackButtonIdentifier }
            .filter { !titleRoles.contains($0.role) }
            .filter { !label(for: $0).isEmpty || $0.frame != nil }
            .prefix(maximumOptions)
            .map { ElementTarget(alias: $0.aliases.alias, role: $0.role, label: label(for: $0)) }
        let fields = entries.filter(isEditable).prefix(maximumOptions)
            .map { ElementTarget(alias: $0.aliases.alias, role: $0.role, label: label(for: $0)) }
        var operations: [Operation] = []
        if !elements.isEmpty {
            operations.append(.tap)
            operations += ElementGesture.allCases.map(Operation.gesture)
        }
        if !texts.isEmpty, !fields.isEmpty {
            operations.append(.enterText)
        }
        operations += SimUseDeviceAction.available(on: snapshot.platform)
            .filter { !excluded.contains($0.optionName) }
            .map(Operation.device)
        operations += [.done, .blocked]
        return ActionMenu(operations: operations, elements: Array(elements), fields: Array(fields), texts: texts)
    }

    static func isEditable(_ entry: UIEntry) -> Bool {
        editableRoles.contains { entry.role.contains($0) }
    }

    /// The element's label, or a stand-in for an unlabelled field so it can still be named.
    static func label(for entry: UIEntry) -> String {
        let label = entry.label.trimmingCharacters(in: .whitespaces)
        guard label.isEmpty, isEditable(entry) else { return String(label.prefix(maximumLabelLength)) }
        return entry.value.map { "field containing \($0.prefix(maximumLabelLength))" } ?? "empty input field"
    }
}

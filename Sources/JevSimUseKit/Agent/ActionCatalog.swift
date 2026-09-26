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
    /// Words on controls that destroy data; tapping one needs the bar for actions going back cannot undo.
    static let destructiveWords = ["削除", "消去", "Delete", "Remove", "Erase"]
    /// Roles that accept typed text.
    static let editableRoles = ["TextField", "SearchField", "TextArea", "EditText"]

    /// The menu for `snapshot`, minus screen-level actions in `excluded` that already did nothing on this screen.
    ///
    /// Every enabled element but a title is a target: some apps expose tappable rows only as `StaticText`
    /// (Reminders), and a tap that does nothing is reported back through `history` rather than guessed away here.
    ///
    /// `explored` names elements whose branch this run already entered and came back from; offering them again made
    /// Jev loop (一般 → back → 一般). Only operations in `allowed` are offered, and targets only for allowed ones.
    /// A menu's full-screen dismiss backdrop (`UISnapshot.backdrop`) is never a target.
    static func menu(
        for snapshot: UISnapshot,
        texts: [InputText],
        excluding excluded: Set<String> = [],
        explored: Set<String> = [],
        allowed: Set<OperationGroup> = OperationGroup.all,
    ) -> ActionMenu {
        let entries = (snapshot.entries ?? []).filter { !$0.isDisabled }
        let backdrop = snapshot.backdrop
        let elements = entries
            .filter { $0 != backdrop }
            .filter { snapshot.platform != SimUseContract.Platform.ios || $0.uniqueId != iOSBackButtonIdentifier }
            .filter { !titleRoles.contains($0.role) && !explored.contains(label(for: $0)) }
            // An unlabelled container (the screen-sized group) gives Jev nothing to choose by.
            .filter { !label(for: $0).isEmpty }
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
        // iOS goes back by the left-edge swipe, which only a navigation stack answers; that stack shows a BackButton.
        // Without one, Jev chose go_back at 0.79-0.88 on a sheet and on a tab's root, and the swipe did nothing or
        // opened an ad. Android's back button always has somewhere to go.
        let canGoBack = snapshot.platform != SimUseContract.Platform.ios
            || entries.contains { $0.uniqueId == iOSBackButtonIdentifier }
        operations += SimUseDeviceAction.available(on: snapshot.platform)
            .filter { !excluded.contains($0.optionName) && ($0 != .goBack || canGoBack) }
            .map(Operation.device)
        operations += [.wait, .done, .blocked]
        operations = operations.filter(allowed.allows)
        let actsOnElements = operations.contains(where: \.actsOnElement)
        return ActionMenu(
            operations: operations, elements: actsOnElements ? Array(elements) : [],
            fields: operations.contains(.enterText) ? Array(fields) : [], texts: texts,
        )
    }

    static func isDestructive(_ label: String) -> Bool {
        destructiveWords.contains { label.localizedCaseInsensitiveContains($0) }
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

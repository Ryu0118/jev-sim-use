/// Builds the choice options offered to Jev for one screen.
enum ActionCatalog {
    /// Jev accepts at most 255 choice options; leave room for pastes, screen-level actions, and `none_of_these`.
    static let maximumOptions = 255
    static let maximumTapTargets = 200
    /// Labels are shortened in option rubrics; the full text stays in the state.
    static let maximumLabelLength = 60
    /// Roles that describe content rather than something to press. An option Jev cannot sensibly pick only
    /// dilutes the distribution (a heading tap looked like progress but changed nothing).
    static let nonInteractiveRoles: Set = ["StaticText", "Heading", "GenericElement", "Group", "Image"]
    /// Roles that only hold text: no gesture does anything to them, so they are not gesture targets either. Unlike
    /// taps, `Group` and `Image` stay, because a map or a photo is what gets pinched or swiped.
    static let textRoles: Set = ["StaticText", "Heading", "GenericElement"]
    /// The accessibility identifier of UIKit's navigation back button. Tapping it does what `go_back` does, and
    /// offering both split Jev's probability (the back button is labelled with the previous screen, such as 一般).
    static let iOSBackButtonIdentifier = "BackButton"
    /// Roles of list rows, where a long sideways swipe can delete the row.
    static let rowRoles: Set = ["Cell", "Row"]

    /// Options for `snapshot`, minus `excluded` option names that already failed to change this screen.
    ///
    /// Screen-level actions and pastes are always offered; taps fill the rest of Jev's option limit.
    static func actions(for snapshot: UISnapshot, texts: [InputText], excluding excluded: Set<String> = []) -> [AgentAction] {
        let fixed = (texts.enumerated().map { AgentAction.paste(index: $0.offset, text: $0.element) }
            + SimUseDeviceAction.available(on: snapshot.platform).map(AgentAction.device))
            .filter { !excluded.contains($0.optionName) }
            .prefix(maximumOptions - 2)
        let taps = (snapshot.entries ?? [])
            .filter { !$0.isDisabled && !nonInteractiveRoles.contains($0.role) && !rubricLabel(for: $0).isEmpty }
            .filter { snapshot.platform != SimUseContract.Platform.ios || $0.uniqueId != iOSBackButtonIdentifier }
            .map { entry in
                let label = String(rubricLabel(for: entry).prefix(maximumLabelLength))
                return AgentAction.tap(alias: entry.aliases.alias, role: entry.role, label: label)
            }
            .filter { !excluded.contains($0.optionName) }
            // One option each for `none_of_these` and the gesture gate `JevStepPlanner` adds.
            .prefix(min(maximumTapTargets, maximumOptions - 2 - fixed.count))
        return Array(taps) + Array(fixed) + [.noneApplies]
    }

    /// Elements Jev may aim a gesture at: enabled elements with a frame that are not plain text, up to the tap limit.
    static func gestureTargets(for snapshot: UISnapshot) -> [GestureTarget] {
        (snapshot.entries ?? [])
            .filter { !$0.isDisabled && $0.frame != nil && !textRoles.contains($0.role) }
            .prefix(maximumTapTargets)
            .map { GestureTarget(alias: $0.aliases.alias, role: $0.role, label: String($0.label.prefix(maximumLabelLength))) }
    }

    /// Unlabelled elements are skipped, except input fields: tapping one focuses it for `--text`.
    static func rubricLabel(for entry: UIEntry) -> String {
        let label = entry.label.trimmingCharacters(in: .whitespaces)
        guard label.isEmpty else { return label }
        let isInput = ["TextField", "SearchField", "TextArea", "EditText"].contains { entry.role.contains($0) }
        return isInput ? (entry.value.map { "field containing \($0)" } ?? "empty input field") : ""
    }
}

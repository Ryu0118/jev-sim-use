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

    /// Options for `snapshot`, minus `excluded` option names that already failed to change this screen.
    ///
    /// Screen-level actions and pastes are always offered; taps fill the rest of Jev's option limit.
    static func actions(for snapshot: UISnapshot, texts: [String], excluding excluded: Set<String> = []) -> [AgentAction] {
        let fixed = (texts.enumerated().map { AgentAction.paste(index: $0.offset, text: $0.element) }
            + SimUseDeviceAction.available(on: snapshot.platform).map(AgentAction.device))
            .filter { !excluded.contains($0.optionName) }
            .prefix(maximumOptions - 1)
        let taps = (snapshot.entries ?? [])
            .filter { !$0.isDisabled && !nonInteractiveRoles.contains($0.role) && !rubricLabel(for: $0).isEmpty }
            .map { entry in
                let label = String(rubricLabel(for: entry).prefix(maximumLabelLength))
                return AgentAction.tap(alias: entry.aliases.alias, role: entry.role, label: label)
            }
            .filter { !excluded.contains($0.optionName) }
            .prefix(min(maximumTapTargets, maximumOptions - 1 - fixed.count))
        return Array(taps) + Array(fixed) + [.noneApplies]
    }

    /// Unlabelled elements are skipped, except input fields: tapping one focuses it for `--text`.
    static func rubricLabel(for entry: UIEntry) -> String {
        let label = entry.label.trimmingCharacters(in: .whitespaces)
        guard label.isEmpty else { return label }
        let isInput = ["TextField", "SearchField", "TextArea", "EditText"].contains { entry.role.contains($0) }
        return isInput ? (entry.value.map { "field containing \($0)" } ?? "empty input field") : ""
    }
}

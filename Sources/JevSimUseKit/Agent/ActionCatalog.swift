/// Builds the choice options offered to Jev for one screen.
enum ActionCatalog {
    /// Jev accepts at most 255 choice options; leave room for pastes, gestures, and `none_of_these`.
    static let maximumOptions = 255
    static let maximumTapTargets = 200
    /// Labels are shortened in option rubrics; the full text stays in the state.
    static let maximumLabelLength = 60
    /// Roles that describe content rather than something to press. An option Jev cannot sensibly pick only
    /// dilutes the distribution (a heading tap looked like progress but changed nothing).
    static let nonInteractiveRoles: Set = ["StaticText", "Heading", "GenericElement", "Group", "Image"]

    /// Options for `snapshot`, minus `excluded` option names that already failed to change this screen.
    static func actions(for snapshot: UISnapshot, texts: [String], excluding excluded: Set<String> = []) -> [AgentAction] {
        let taps = (snapshot.entries ?? [])
            .filter { !$0.isDisabled && !nonInteractiveRoles.contains($0.role) && !rubricLabel(for: $0).isEmpty }
            .prefix(maximumTapTargets)
            .map { entry in
                let label = String(rubricLabel(for: entry).prefix(maximumLabelLength))
                return AgentAction.tap(alias: entry.aliases.alias, role: entry.role, label: label)
            }
        let pastes = texts.enumerated().map { AgentAction.paste(index: $0.offset, text: $0.element) }
        let gestures: [SimUseDeviceAction] = [.revealContentBelow, .revealContentAbove, .goBack]
        let candidates = (taps + pastes + gestures.map(AgentAction.device)).filter { !excluded.contains($0.optionName) }
        return Array(candidates.prefix(maximumOptions - 1)) + [.noneApplies]
    }

    /// Unlabelled elements are skipped, except input fields: tapping one focuses it for `--text`.
    static func rubricLabel(for entry: UIEntry) -> String {
        let label = entry.label.trimmingCharacters(in: .whitespaces)
        guard label.isEmpty else { return label }
        let isInput = ["TextField", "SearchField", "TextArea", "EditText"].contains { entry.role.contains($0) }
        return isInput ? (entry.value.map { "field containing \($0)" } ?? "empty input field") : ""
    }
}

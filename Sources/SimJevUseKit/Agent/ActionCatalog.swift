/// Builds the choice options offered to Jev for one screen.
enum ActionCatalog {
    /// Jev's state plus the longest question must fit in 32k tokens, and the outline
    /// already carries the whole screen, so the tap options are capped.
    static let maximumTapTargets = 40
    /// Labels are shortened in option rubrics; the full text stays in the outline.
    static let maximumLabelLength = 60

    static func actions(for snapshot: UISnapshot, texts: [String]) -> [AgentAction] {
        let taps = (snapshot.entries ?? [])
            .filter { !$0.isDisabled && !rubricLabel(for: $0).isEmpty }
            .prefix(maximumTapTargets)
            .map { entry in
                let label = String(rubricLabel(for: entry).prefix(maximumLabelLength))
                return AgentAction.tap(alias: entry.aliases.alias, role: entry.role, label: label)
            }
        let pastes = texts.enumerated().map { AgentAction.paste(index: $0.offset, text: $0.element) }
        let gestures: [SimUseDeviceAction] = [.revealContentBelow, .revealContentAbove, .goBack]
        return taps + pastes + gestures.map(AgentAction.device)
    }

    /// Unlabelled elements are skipped, except input fields: tapping one focuses it for `--text`.
    static func rubricLabel(for entry: UIEntry) -> String {
        let label = entry.label.trimmingCharacters(in: .whitespaces)
        guard label.isEmpty else { return label }
        let isInput = ["TextField", "SearchField", "TextArea", "EditText"].contains { entry.role.contains($0) }
        return isInput ? (entry.value.map { "field containing \($0)" } ?? "empty input field") : ""
    }
}

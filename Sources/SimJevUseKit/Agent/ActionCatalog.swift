/// Builds the choice options offered to Jev for one screen.
enum ActionCatalog {
    /// Jev's state plus the longest question must fit in 32k tokens, and the outline
    /// already carries the whole screen, so the tap options are capped.
    static let maximumTapTargets = 40
    /// Labels are shortened in option rubrics; the full text stays in the outline.
    static let maximumLabelLength = 60

    static func actions(for snapshot: UISnapshot, texts: [String]) -> [AgentAction] {
        let taps = (snapshot.entries ?? [])
            .filter { !$0.isDisabled && !$0.label.trimmingCharacters(in: .whitespaces).isEmpty }
            .prefix(maximumTapTargets)
            .map { entry in
                let label = String(entry.label.prefix(maximumLabelLength))
                return AgentAction.tap(alias: entry.aliases.alias, role: entry.role, label: label)
            }
        let pastes = texts.enumerated().map { AgentAction.paste(index: $0.offset, text: $0.element) }
        let gestures: [SimUseDeviceAction] = [.revealContentBelow, .revealContentAbove, .goBack]
        return taps + pastes + gestures.map(AgentAction.device)
    }
}

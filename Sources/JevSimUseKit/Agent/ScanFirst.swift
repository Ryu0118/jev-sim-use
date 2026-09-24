/// Looks one page further down a list before letting Jev open a section the goal does not name.
///
/// Jev reliably dove into 一般 when asked for デベロッパ, which sits further down Settings; rules and rubrics did not
/// shift that prior (0.51-0.77 for 一般 across runs). The check is deterministic and narrow: the goal must name items
/// in the screen's script, none of them (and nothing else the goal names) may be visible, the screen must be a list,
/// and it runs once per screen title. Maps, photos, and screens where the goal's path is visible are left to Jev.
enum ScanFirst {
    /// The scroll to run instead of `plan`'s action, or `nil` to follow Jev.
    static func override(
        _ plan: StepPlan,
        on snapshot: UISnapshot,
        goal: String,
        notes: [String],
        alreadyScanned: Bool,
        tried: Set<String>,
    ) -> AgentAction? {
        switch plan.action {
        case .tap, .noneApplies: break
        default: return nil
        }
        let scroll = AgentAction.device(.revealContentBelow)
        guard !alreadyScanned, !tried.contains(scroll.optionName), snapshot.appLabel != "SpringBoard",
              snapshot.looksLikeList
        else { return nil }
        let terms = namedTerms(in: ([goal] + notes).joined(separator: " "))
        let labels = (snapshot.entries ?? []).map(\.label)
        guard !terms.isEmpty, !terms.contains(where: { term in labels.contains { $0.contains(term) } }) else { return nil }
        return scroll
    }

    /// Runs of two or more non-ASCII letters: the item names a goal quotes from a Japanese (or other non-Latin) UI.
    static func namedTerms(in text: String) -> [String] {
        text.split { !($0.isLetter && !$0.isASCII) && $0 != "ー" }
            .map(String.init)
            .filter { $0.count >= 2 }
    }
}

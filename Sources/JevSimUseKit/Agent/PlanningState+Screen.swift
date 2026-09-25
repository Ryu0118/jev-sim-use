extension PlanningState {
    /// The current screen as Jev sees it.
    struct Screen: Encodable, Sendable {
        let app: String?
        /// The navigation title, as jev-use sends the window title: it says which screen this is.
        let title: String?
        /// The back button's label (the previous screen), present only when there is somewhere to go back to.
        let back: String?
        let elements: [Element]

        init(_ snapshot: UISnapshot, texts: [InputText] = []) {
            app = snapshot.appLabel
            let entries = snapshot.entries ?? []
            title = snapshot.title
            back = entries.first { $0.uniqueId == ActionCatalog.iOSBackButtonIdentifier }?.label
            elements = (snapshot.entries ?? []).map {
                Element($0, coveredBy: snapshot.cover(of: $0), slider: snapshot.caption(ofSlider: $0))
                    .showing(texts)
            }
        }
    }

    /// One on-screen element; empty or absent attributes are omitted to save tokens.
    struct Element: Encodable, Sendable {
        let id: String
        let role: String
        let label: String?
        let identifier: String?
        let value: String?
        let states: [String]?
        let region: String?
        let coveredBy: String?
        /// Names of `-t` texts this element displays: a memo titled with `title` shows the `title` text.
        private(set) var showsText: [String]?

        private enum CodingKeys: String, CodingKey {
            case id, role, label, identifier, value, states, region
            case coveredBy = "covered_by"
            case showsText = "shows_text"
        }

        init(_ entry: UIEntry, coveredBy cover: UIEntry? = nil, slider caption: SliderCaption? = nil) {
            id = PlanningState.elementID(entry.aliases.alias)
            role = entry.role
            label = caption?.label ?? (entry.label.isEmpty ? nil : entry.label)
            identifier = entry.uniqueId
            value = caption?.value ?? Self.readableValue(entry)
            // A tap leaves a slider where it is; D2 tapped 記録間隔 twice at 0.87 without moving it.
            let adjusting = entry.isSlider ? [Self.sliderUsage] : []
            let allStates = entry.states + adjusting
            states = allStates.isEmpty ? nil : allStates
            region = entry.region.map { region in region.label.map { "\(region.kind): \($0)" } ?? region.kind }
            coveredBy = cover.map { $0.label.isEmpty ? $0.role : $0.label }
        }
    }
}

extension PlanningState.Element {
    /// Marks the named texts whose value this element displays. Jev sees only a text's name, never its value, so
    /// after saving a memo titled with `title` it could not tell which row was "that memo" (0.41). The label is
    /// already in the state; the mark adds only the name. A masked password never matches.
    func showing(_ texts: [InputText]) -> Self {
        let shown = texts.filter { text in
            text.value.count >= 2 && [label, value].contains { $0?.contains(text.value) == true }
        }
        guard !shown.isEmpty else { return self }
        var marked = self
        marked.showsText = shown.map(\.name)
        return marked
    }

    /// How a slider moves, since a tap does not move it.
    static let sliderUsage = "adjustable: swipe_right raises it, swipe_left lowers it; a tap does not change it"

    /// Jev reads `"on"` / `"off"` as a state far more reliably than a toggle's `"1"` / `"0"`.
    static func readableValue(_ entry: UIEntry) -> String? {
        guard entry.isToggle else { return entry.value }
        return switch entry.value {
        case "1": "on"
        case "0": "off"
        default: entry.value
        }
    }
}

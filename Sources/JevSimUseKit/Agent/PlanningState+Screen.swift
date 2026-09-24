extension PlanningState {
    /// The current screen as Jev sees it.
    struct Screen: Encodable, Sendable {
        let app: String?
        let elements: [Element]

        init(_ snapshot: UISnapshot) {
            app = snapshot.appLabel
            elements = (snapshot.entries ?? []).map { Element($0, coveredBy: snapshot.cover(of: $0)) }
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

        private enum CodingKeys: String, CodingKey {
            case id, role, label, identifier, value, states, region
            case coveredBy = "covered_by"
        }

        init(_ entry: UIEntry, coveredBy cover: UIEntry? = nil) {
            id = PlanningState.elementID(entry.aliases.alias)
            role = entry.role
            label = entry.label.isEmpty ? nil : entry.label
            identifier = entry.uniqueId
            value = Self.readableValue(entry)
            states = entry.states.isEmpty ? nil : entry.states
            region = entry.region.map { region in region.label.map { "\(region.kind): \($0)" } ?? region.kind }
            coveredBy = cover.map { $0.label.isEmpty ? $0.role : $0.label }
        }
    }
}

extension PlanningState.Element {
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

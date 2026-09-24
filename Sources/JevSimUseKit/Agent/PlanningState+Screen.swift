extension PlanningState {
    /// The current screen as Jev sees it.
    struct Screen: Encodable, Sendable {
        let app: String?
        let elements: [Element]

        init(_ snapshot: UISnapshot) {
            app = snapshot.appLabel
            elements = (snapshot.entries ?? []).map(Element.init)
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

        init(_ entry: UIEntry) {
            id = PlanningState.elementID(entry.aliases.alias)
            role = entry.role
            label = entry.label.isEmpty ? nil : entry.label
            identifier = entry.uniqueId
            value = Self.readableValue(entry)
            states = entry.states.isEmpty ? nil : entry.states
            region = entry.region.map { region in region.label.map { "\(region.kind): \($0)" } ?? region.kind }
        }
    }
}

extension PlanningState.Element {
    /// Toggle roles report `"1"` / `"0"`; Jev reads `"on"` / `"off"` as a state far more reliably.
    static let toggleRoles: Set = ["CheckBox", "Switch", "Toggle"]

    static func readableValue(_ entry: UIEntry) -> String? {
        guard toggleRoles.contains(entry.role) else { return entry.value }
        return switch entry.value {
        case "1": "on"
        case "0": "off"
        default: entry.value
        }
    }
}

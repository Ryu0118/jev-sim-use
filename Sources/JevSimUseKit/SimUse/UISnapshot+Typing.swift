import Foundation

extension UISnapshot {
    /// Whether `text`, pasted into the field `@alias` of this reading, shows in `fresh`: `true` or `false`, or `nil`
    /// when the field is no longer there (a search that ran on paste replaced the screen). The comparison stays on this
    /// machine; the value is never sent to Jev or shown.
    ///
    /// The field landed the text when it now holds it, compared by letters and digits alone, since a field can format
    /// what it takes (a phone number gains brackets). A field that held nothing, or its placeholder, which iOS reports
    /// as a value equal to the label, also landed it when it now shows anything else: a secure field shows bullets,
    /// and a date field may rewrite the text entirely.
    func typedText(_ text: String, landedIn alias: Int, after fresh: UISnapshot) -> Bool? {
        guard let before = entry(alias: alias), let after = fresh.sameField(as: before) else { return nil }
        let wanted = Self.comparable(text)
        guard !wanted.isEmpty else { return nil }
        if Self.comparable(after.value ?? "").contains(wanted) {
            return true
        }
        let wasEmpty = [nil, "", before.label].contains(before.value)
        let nowShows = ![nil, "", after.label].contains(after.value)
        return wasEmpty && nowShows && after.value != before.value
    }

    /// The element with `field`'s role, label, and identifier, the nearest one when several match: focusing a search
    /// field narrowed it to make room for its Cancel button, so its frame is not compared.
    private func sameField(as field: UIEntry) -> UIEntry? {
        let center = field.frame?.center ?? (x: 0, y: 0)
        return (entries ?? [])
            .filter { $0.role == field.role && $0.label == field.label && $0.uniqueId == field.uniqueId }
            .min { distance($0, center) < distance($1, center) }
    }

    private func distance(_ entry: UIEntry, _ point: (x: Double, y: Double)) -> Double {
        guard let center = entry.frame?.center else { return .infinity }
        return abs(center.x - point.x) + abs(center.y - point.y)
    }

    /// `text` reduced to its letters and digits, case-folded.
    private static func comparable(_ text: String) -> String {
        String(text.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init))
    }
}

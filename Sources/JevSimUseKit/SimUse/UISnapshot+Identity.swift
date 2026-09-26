extension UISnapshot {
    /// What makes two readings the same screen: the elements and their state, without frames or screen bands.
    ///
    /// A scroll that bounces at the end of a list moves every frame, and can move an element into another band, yet
    /// shows the same elements. Without `entries` (physical iOS devices) the text outline is all there is.
    var identity: String {
        guard let entries, !entries.isEmpty else { return outline }
        let elements = entries.map { entry in
            [entry.role, entry.label, entry.value ?? "", entry.uniqueId ?? "", entry.states.joined(separator: ",")]
                .joined(separator: "|")
        }
        return ([appLabel ?? ""] + elements).joined(separator: "\n")
    }
}

extension UISnapshot {
    /// Which elements are where, without their values: two readings with the same layout show the same controls in
    /// the same places. Values are left out because some change on their own (a row reading "12 seconds ago"), and
    /// requiring them to match kept a list of recent items from ever reading the same twice.
    var layout: String {
        guard let entries, !entries.isEmpty else { return outline }
        let elements = entries.map { entry in
            let frame = entry.frame.map { "\($0.x),\($0.y),\($0.width),\($0.height)" } ?? ""
            return [entry.role, entry.label, entry.uniqueId ?? "", frame].joined(separator: "|")
        }
        return ([appLabel ?? ""] + elements).joined(separator: "\n")
    }
}

extension UISnapshot {
    /// Which elements show, without values, frames, or bands: what stays put while a relative time ("12 minutes ago")
    /// ticks. Too coarse for telling whether an action worked (typing and toggles change only values), so it serves
    /// only to spot the same action repeated on what is essentially the same screen.
    var skeleton: String {
        guard let entries, !entries.isEmpty else { return outline }
        let elements = entries.map { entry in
            let states = entry.states.filter { !$0.hasPrefix("value=") }
            return [entry.role, entry.label, entry.uniqueId ?? "", states.joined(separator: ",")].joined(separator: "|")
        }
        return ([appLabel ?? ""] + elements).joined(separator: "\n")
    }
}

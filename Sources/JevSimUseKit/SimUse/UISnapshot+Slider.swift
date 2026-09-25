/// What a slider controls and shows, for a slider whose accessibility label is only its raw position.
struct SliderCaption: Equatable {
    /// The setting's name, from the text just above the slider.
    let label: String
    /// The value as the app displays it on the same row as the name, such as `25 m`.
    let value: String?
}

extension UIEntry {
    /// Whether the element is a slider.
    var isSlider: Bool {
        role == "Slider"
    }
}

extension UISnapshot {
    /// The name and displayed value of `slider`, when its own label is just a number.
    ///
    /// SwiftUI sliders often expose `0.1206…` as their label (a recording-interval setting), so Jev could not tell which
    /// setting it was or what it showed. The name is the nearest text above the slider; the displayed value is the
    /// other text on that name's row.
    func caption(ofSlider slider: UIEntry) -> SliderCaption? {
        guard slider.isSlider, slider.label.isEmpty || Double(slider.label) != nil, let track = slider.frame else {
            return nil
        }
        let texts: [(label: String, frame: ElementFrame)] = (entries ?? []).compactMap { entry in
            guard entry.role == "StaticText", !entry.label.isEmpty, let frame = entry.frame else { return nil }
            return (entry.label, frame)
        }
        // The caption row sits just above the track.
        let above = texts.filter { text in
            let gap = track.y - (text.frame.y + text.frame.height)
            return gap >= -2 && gap <= 40
        }
        guard let name = above.min(by: { $0.frame.x < $1.frame.x }) else { return nil }
        let row = above.filter { $0.frame.x > name.frame.x && abs($0.frame.center.y - name.frame.center.y) < 4 }
        return SliderCaption(label: name.label, value: row.max { $0.frame.x < $1.frame.x }?.label)
    }
}

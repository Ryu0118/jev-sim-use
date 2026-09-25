import Foundation
@testable import JevSimUseKit
import Testing

@Suite("A slider labelled only by its position is named from its row")
struct SliderTests {
    /// DriveTracker's 記録間隔 row: the name and the shown value above a slider whose label is its raw position.
    private let interval = Fixtures.entry(21, "記録間隔", role: "StaticText", frame: ElementFrame(x: 32, y: 614, width: 64, height: 20))
    private let shown = Fixtures.entry(22, "25 m", role: "StaticText", frame: ElementFrame(x: 331, y: 614, width: 39, height: 20))
    private let slider = UIEntry(
        aliases: ElementAliases(alias: 23), role: "Slider", label: "0.12060301750898361", states: [],
        value: "0.12060301750898361", uniqueId: nil, region: nil, frame: ElementFrame(x: 46, y: 638, width: 294, height: 31),
    )

    @Test("names the slider after the text above it and shows the value the app displays")
    func caption() {
        let snapshot = Fixtures.snapshot(entries: [interval, shown, slider])
        #expect(snapshot.caption(ofSlider: slider) == SliderCaption(label: "記録間隔", value: "25 m"))
        let element = PlanningState.Element(slider, slider: snapshot.caption(ofSlider: slider))
        #expect(element.label == "記録間隔")
        #expect(element.value == "25 m")
        #expect(element.states == [PlanningState.Element.sliderUsage])
    }
}

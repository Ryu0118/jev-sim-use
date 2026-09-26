@testable import JevSimUseKit
import Testing

/// Which heading names the screen. Frames and bands follow real iOS 26 readings: a large title, a collapsed one, a
/// sheet with only section headings, and a date header under a row of day buttons.
struct ScreenTitleTests {
    private static let content = ElementRegion(kind: "Content", label: nil)

    private static func heading(_ label: String, y: Double, band: String = "Content") -> UIEntry {
        Fixtures.entry(9, label, role: "Heading", frame: ElementFrame(x: 16, y: y, width: 370, height: 32), region: ElementRegion(kind: band, label: nil))
    }

    private static func item(_ alias: Int, _ role: String, y: Double, height: Double = 28) -> UIEntry {
        Fixtures.entry(alias, "item \(alias)", role: role, frame: ElementFrame(x: 16, y: y, width: 370, height: height), region: content)
    }

    @Test("does not name a sheet after a section heading below its fields, and sends no title rather than a wrong one")
    func sectionHeadingIsNotTitle() {
        let sheet = Fixtures.snapshot(entries: [
            Fixtures.entry(1, "", role: "Group", frame: ElementFrame(x: 0, y: 78, width: 402, height: 54), region: ElementRegion(kind: "Top", label: nil)),
            Self.item(2, "TextField", y: 156), Self.item(3, "Button", y: 224, height: 22), Self.heading("Location", y: 288),
        ])
        #expect(sheet.title == nil)
    }

    @Test("keeps a large title at the top of the content, with only a screen-sized container around it")
    func largeTitle() {
        let list = Fixtures.snapshot(entries: [
            Fixtures.entry(1, "", role: "Group", frame: ElementFrame(x: 0, y: 0, width: 402, height: 874), region: Self.content),
            Self.heading("Home", y: 120), Self.item(2, "Button", y: 178),
        ])
        #expect(list.title == "Home")
    }

    @Test("keeps a collapsed title in the top bar whatever the content holds")
    func collapsedTitle() {
        let screen = Fixtures.snapshot(entries: [Self.item(1, "PopUpButton", y: 167), Self.heading("Info", y: 90, band: "Top"), Self.heading("Tags", y: 265)])
        #expect(screen.title == "Info")
    }

    @Test("does not take a header below a row of controls for the title")
    func headerBelowControls() {
        let day = Fixtures.snapshot(entries: [Self.item(1, "Button", y: 133, height: 43), Self.heading("A date", y: 192)])
        #expect(day.title == nil)
    }
}

/// An element's rectangle in screen points, as sim-use reports it.
package struct ElementFrame: Decodable, Sendable, Hashable {
    /// Leading edge.
    package let x: Double
    /// Top edge.
    package let y: Double
    /// Width.
    package let width: Double
    /// Height.
    package let height: Double

    package init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// The centre of an iOS switch in a row with this frame. The switch (51 pt wide) sits at the trailing edge, and
    /// a tap at the row's centre does not flip it.
    package var switchCenter: (x: Double, y: Double) {
        (x: max(x + width / 2, x + width - 26), y: y + height / 2)
    }
}

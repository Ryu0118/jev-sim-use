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

    /// The frame's centre.
    package var center: (x: Double, y: Double) {
        (x: x + width / 2, y: y + height / 2)
    }
}

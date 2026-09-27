/// Where one step's time went, in seconds of the loop's own waiting: the parts never overlap, so they add up to the
/// step's time. The confirming read that runs while Jev plans counts only for the time the loop waited for it after
/// Jev answered.
package struct StepTiming: Codable, Sendable, Hashable, CustomStringConvertible {
    /// Waiting for `sim-use ui` readings: settling and the wait for an unchanged screen.
    package var read: Double = 0
    /// Waiting for Jev, the retry with hints included.
    package var jev: Double = 0
    /// Taking the action; a tap that scrolls its element into reach includes the readings that follow the scroll.
    package var act: Double = 0
    /// Reading on before a hand-over, in case the screen moves on. Counted as reading, this wait made every stopped
    /// step look like a slow first read.
    package var handOver: Double = 0

    /// The step's time.
    package var total: Double {
        read + jev + act + handOver
    }

    /// The parts, compactly: `read 0.61s, jev 0.24s, act 0.20s`, with `hand-over 5.00s` when the step waited to stop.
    package var description: String {
        "read \(Self.format(read)), jev \(Self.format(jev)), act \(Self.format(act))"
            + (handOver > 0 ? ", hand-over \(Self.format(handOver))" : "")
    }

    package init(read: Double = 0, jev: Double = 0, act: Double = 0, handOver: Double = 0) {
        self.read = read
        self.jev = jev
        self.act = act
        self.handOver = handOver
    }

    private enum CodingKeys: String, CodingKey {
        case read, jev, act
        case handOver = "hand_over"
    }

    /// Timings saved before the hand-over part existed have no `hand_over`.
    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        read = try container.decode(Double.self, forKey: .read)
        jev = try container.decode(Double.self, forKey: .jev)
        act = try container.decode(Double.self, forKey: .act)
        handOver = try container.decodeIfPresent(Double.self, forKey: .handOver) ?? 0
    }

    /// Seconds with two decimals.
    package static func format(_ seconds: Double) -> String {
        seconds.formatted(.number.precision(.fractionLength(2))) + "s"
    }

    /// Both timings' parts added.
    static func + (lhs: Self, rhs: Self) -> Self {
        Self(read: lhs.read + rhs.read, jev: lhs.jev + rhs.jev, act: lhs.act + rhs.act, handOver: lhs.handOver + rhs.handOver)
    }

    /// Adds `rhs`'s parts to `lhs`'s.
    static func += (lhs: inout Self, rhs: Self) {
        lhs = lhs + rhs
    }

    /// Runs `body` and adds the time it took to `part`.
    mutating func add<T>(to part: WritableKeyPath<Self, Double>, _ body: () async throws -> T) async rethrows -> T {
        let clock = ContinuousClock()
        let start = clock.now
        defer { self[keyPath: part] += (clock.now - start) / .seconds(1) }
        return try await body()
    }
}

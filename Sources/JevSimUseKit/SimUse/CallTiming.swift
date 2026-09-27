/// What a sim-use call does, for its deadline: a screen read, or an action whose own duration is added.
package enum CallKind: Sendable, Hashable {
    /// A `ui` read, or `keyboard-state`.
    case read
    /// A tap, gesture, swipe, paste, key, or button.
    case action
}

/// How long sim-use calls may take before they count as hung.
package struct CallTimingPolicy: Sendable, Hashable {
    /// The shortest deadline, whatever the baseline.
    package var floor: Duration
    /// The deadline as a multiple of the baseline.
    package var factor: Double
    /// How many recent calls the baseline is the median of.
    package var window: Int
    /// The largest baseline, so calls that were slow but answered cannot stretch deadlines without end.
    package var ceiling: Duration
    /// The deadline before `coldSamples` calls were timed.
    package var coldStart: Duration
    /// Calls timed before the baseline is used.
    package var coldSamples: Int

    /// Creates a policy.
    package init(floor: Duration, factor: Double, window: Int, ceiling: Duration, coldStart: Duration, coldSamples: Int) {
        self.floor = floor
        self.factor = factor
        self.window = window
        self.ceiling = ceiling
        self.coldStart = coldStart
        self.coldSamples = coldSamples
    }

    /// The live policy.
    package static let standard = CallTimingPolicy(
        floor: .seconds(3), factor: 4, window: 15, ceiling: .seconds(4), coldStart: .seconds(3), coldSamples: 3,
    )

    /// The time an action takes by its own arguments.
    static func intrinsicDuration(of _: [String]) -> Duration {
        .zero
    }
}

/// Recent sim-use call durations for one device.
package final class CallBaselines: Sendable {
    /// The policy deadlines follow.
    let policy: CallTimingPolicy

    /// Creates empty baselines.
    package init(policy: CallTimingPolicy = .standard) {
        self.policy = policy
    }

    /// Records a call that answered in `duration`.
    func record(_: CallKind, _: Duration) {}

    /// The deadline for the next call of `kind`, with `intrinsic` added for an action.
    func deadline(for _: CallKind, intrinsic: Duration = .zero) -> Duration {
        policy.floor + intrinsic
    }

    /// The current baseline for `kind`, once enough calls were timed.
    func baseline(_: CallKind) -> Duration? {
        nil
    }
}

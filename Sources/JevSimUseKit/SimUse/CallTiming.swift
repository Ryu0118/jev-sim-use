import Synchronization

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

    /// The live policy, from `ui` reads on an iOS 26 simulator: a median of 0.62 s, a 99th percentile 5.7 times that and
    /// a slowest read 7.6 times it (3.5 s and 4.7 s) under light load, while a hung daemon answered in 10-20 s or never.
    /// A factor of 8 keeps the slowest healthy read under the deadline (5 s at that median); the 3 s floor still catches
    /// a hang on a fast device. The ceiling stops a stretch of slow reads that did answer from pushing a read's deadline
    /// past 32 s. A run's first read also starts the daemon, so it gets 15 s; two samples end the cold start, since a
    /// daemon frozen early left no read to record and kept every later read at 15 s.
    package static let standard = CallTimingPolicy(
        floor: .seconds(3), factor: 8, window: 15, ceiling: .seconds(4), coldStart: .seconds(15), coldSamples: 2,
    )

    /// The time an action takes by its own arguments: its `--duration`, or sim-use's default hold for a long-press
    /// (0.8 s) and a swipe or gesture preset (0.5 s); a tap, paste, or key has none worth counting.
    static func intrinsicDuration(of arguments: [String]) -> Duration {
        let flag = SimUseContract.Gesture.duration
        let value = arguments.lazy.compactMap { argument -> String? in
            argument.hasPrefix(flag + "=") ? String(argument.dropFirst(flag.count + 1)) : nil
        }.first ?? arguments.firstIndex(of: flag).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        if let value, let seconds = Double(value), arguments.first != SimUseContract.Command.tap {
            return .milliseconds(Int(seconds * 1000))
        }
        return switch arguments.first {
        case SimUseContract.Command.longPress: .milliseconds(800)
        case SimUseContract.Command.swipe, SimUseContract.Command.gesture, SimUseContract.MultiTouch.command: .milliseconds(500)
        default: .zero
        }
    }
}

/// Recent sim-use call durations for one device, and the deadlines they give: a read's is `factor` times the median
/// of recent reads, an action's the same over its overhead (its time past its own duration) plus that duration, never
/// below `floor`. Only calls that answered are recorded, so a hang never stretches the next deadline.
package final class CallBaselines: Sendable {
    /// The policy deadlines follow.
    let policy: CallTimingPolicy
    private let samples = Mutex((reads: [Duration](), actions: [Duration](), lastApp: String?.none))

    /// Creates empty baselines.
    package init(policy: CallTimingPolicy = .standard) {
        self.policy = policy
    }

    /// Records a call of `kind` that answered in `duration`; for an action, `duration` is its overhead.
    func record(_ kind: CallKind, _ duration: Duration) {
        samples.withLock { samples in
            switch kind {
            case .read: samples.reads = Array((samples.reads + [duration]).suffix(policy.window))
            case .action: samples.actions = Array((samples.actions + [duration]).suffix(policy.window))
            }
        }
    }

    /// The deadline for the next call of `kind`, with `intrinsic` added for an action.
    func deadline(for kind: CallKind, intrinsic: Duration = .zero) -> Duration {
        // A run's first actions come after its reads started the daemon, so the read baseline stands in for theirs;
        // a first hung gesture waited the whole cold start (17 s) otherwise.
        guard let baseline = baseline(kind) ?? (kind == .action ? baseline(.read, samples: 1) : nil) else {
            return policy.coldStart + intrinsic
        }
        return max(policy.floor, baseline * policy.factor) + intrinsic
    }

    /// The median of recent calls of `kind`, capped at the ceiling, once `coldSamples` were timed.
    func baseline(_ kind: CallKind, samples minimum: Int? = nil) -> Duration? {
        let recent = samples.withLock { kind == .read ? $0.reads : $0.actions }
        guard recent.count >= (minimum ?? policy.coldSamples), !recent.isEmpty else { return nil }
        return min(recent.sorted()[recent.count / 2], policy.ceiling)
    }

    /// The app the last read showed, to tell whether it disappeared across a daemon replacement.
    var lastApp: String? {
        get { samples.withLock { $0.lastApp } }
        set { samples.withLock { $0.lastApp = newValue } }
    }
}

/// The deadlines a device's sim-use calls get now.
package struct CallDeadlines: Sendable, Hashable {
    /// A read's deadline.
    package var read: Duration
    /// The deadline of the longest action offered, a 1.5 s scroll.
    package var action: Duration
    /// The read baseline, when it stretched the read deadline past the floor.
    package var stretchedReadBaseline: Duration?
}

extension CallBaselines {
    /// The deadlines calls get now.
    var deadlines: CallDeadlines {
        let baseline = baseline(.read)
        return CallDeadlines(
            read: deadline(for: .read), action: deadline(for: .action, intrinsic: .milliseconds(1500)),
            stretchedReadBaseline: baseline.flatMap { $0 * policy.factor > policy.floor ? $0 : nil },
        )
    }
}

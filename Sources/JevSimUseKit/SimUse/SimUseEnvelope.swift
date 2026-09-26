/// The `--json` envelope every `sim-use` command prints on stdout, success or failure.
///
/// Decoded leniently: sim-use adds keys between releases, so unknown keys are ignored
/// and everything that is not always present is optional.
struct SimUseEnvelope<Payload: Decodable & Sendable>: Decodable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case succeeded = "ok"
        case data
        case error
        case hint
        case process
        case advisory
    }

    let succeeded: Bool
    let data: Payload?
    let error: String?
    let hint: String?
    let process: ProcessReport?
    /// A caveat about how sim-use read the result, such as an orientation it assumed rather than confirmed.
    let advisory: Advisory?
}

/// A caveat sim-use attaches to an otherwise successful envelope.
struct Advisory: Decodable, Sendable {
    /// `orientation_calibration_fallback` when sim-use assumed the orientation.
    let kind: String
}

/// App liveness events sim-use attaches to an envelope.
struct ProcessReport: Decodable, Sendable {
    /// One liveness change, such as the target app disappearing.
    struct Event: Decodable, Sendable {
        let kind: String
        let bundleId: String?
    }

    let events: [Event]?

    /// Bundle ids of apps that disappeared since the previous command.
    var disappearedBundleIDs: [String] {
        (events ?? []).filter { $0.kind == "disappeared" }.map { $0.bundleId ?? "unknown app" }
    }
}

/// A payload for commands whose `data` is empty or irrelevant.
struct EmptyPayload: Decodable, Sendable {}

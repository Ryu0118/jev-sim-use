/// Everything the user asked for in one `run` or `session resume`.
package struct RunGoalRequest: Sendable, Equatable {
    /// Start a new session, or continue one.
    package var session: SessionStart
    /// Upper bound on actions in this run.
    package var maxSteps: Int
    /// Stop and hand over below this confidence.
    package var minConfidence: Double
    /// `--device`, or `nil` to use the session's device, then `$SIM_USE_DEVICE`, then the only usable device.
    package var deviceID: String?
    /// `--base-url`, if given.
    package var baseURL: String?
    /// `--model`, if given.
    package var model: String?

    package init(
        session: SessionStart,
        maxSteps: Int,
        minConfidence: Double,
        deviceID: String?,
        baseURL: String?,
        model: String?,
    ) {
        self.session = session
        self.maxSteps = maxSteps
        self.minConfidence = minConfidence
        self.deviceID = deviceID
        self.baseURL = baseURL
        self.model = model
    }
}

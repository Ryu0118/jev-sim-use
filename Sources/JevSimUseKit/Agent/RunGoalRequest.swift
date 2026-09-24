/// Everything the user asked for in one `run`.
package struct RunGoalRequest: Sendable, Equatable {
    /// The goal in natural language.
    package var goal: String
    /// Texts the agent may paste.
    package var texts: [String]
    /// Upper bound on actions.
    package var maxSteps: Int
    /// Stop and hand over below this confidence.
    package var minConfidence: Double
    /// `--device`, or `nil` to fall back to `$SIM_USE_DEVICE` and then the only usable device.
    package var deviceID: String?
    /// `--base-url`, if given.
    package var baseURL: String?
    /// `--model`, if given.
    package var model: String?

    package init(
        goal: String,
        texts: [String],
        maxSteps: Int,
        minConfidence: Double,
        deviceID: String?,
        baseURL: String?,
        model: String?,
    ) {
        self.goal = goal
        self.texts = texts
        self.maxSteps = maxSteps
        self.minConfidence = minConfidence
        self.deviceID = deviceID
        self.baseURL = baseURL
        self.model = model
    }
}

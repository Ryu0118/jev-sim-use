/// The connection options `doctor` checks.
package struct DoctorRequest: Sendable, Equatable {
    /// `--device`, if given.
    package var deviceID: String?
    /// `--base-url`, if given.
    package var baseURL: String?
    /// `--model`, if given.
    package var model: String?

    package init(deviceID: String?, baseURL: String?, model: String?) {
        self.deviceID = deviceID
        self.baseURL = baseURL
        self.model = model
    }
}

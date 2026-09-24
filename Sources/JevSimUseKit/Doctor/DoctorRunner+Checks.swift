extension DoctorRunner {
    func simUseDetail() async throws -> String {
        let (executable, version) = try await bootstrap.verifyInstallation()
        let detail = "\(version) at \(executable.path(percentEncoded: false))"
        return version > SimUseBootstrap.testedVersion ? detail + " (newer than tested \(SimUseBootstrap.testedVersion))" : detail
    }

    /// Reads the screen once so a change in sim-use's JSON shows up here rather than mid-run.
    func deviceDetail(_ deviceID: String?) async throws -> String {
        let connection = try await bootstrap.connect(
            deviceID: SimUseBootstrap.deviceID(flag: deviceID, environment: environment),
        )
        let snapshot = try await connection.client.observe().snapshot
        let device = connection.client.device
        return "\(device.name) (\(device.deviceId)); screen readable, \(snapshot.entries?.count ?? 0) elements"
    }

    func jevDetail(_ request: DoctorRequest) throws -> String {
        let settings = try JevSettings.resolve(
            baseURLFlag: request.baseURL, modelFlag: request.model, config: configStore.load(), environment: environment,
        )
        return "\(settings.model) at \(settings.endpoint), API key set"
    }
}

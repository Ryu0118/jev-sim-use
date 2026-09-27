/// Checks that sim-use, a device, and the Jev settings are ready, without calling Jev.
package struct DoctorRunner: Sendable {
    let bootstrap: SimUseBootstrap
    let configStore: UserConfigStore
    let environment: [String: String]

    package init(bootstrap: SimUseBootstrap, configStore: UserConfigStore, environment: [String: String]) {
        self.bootstrap = bootstrap
        self.configStore = configStore
        self.environment = environment
    }

    /// Runs every check; a failure never stops the later independent checks.
    package func run(_ request: DoctorRequest) async -> DoctorReport {
        let simUse = await check("sim-use") { try await simUseDetail() }
        let device: DoctorCheck = if case .passed = simUse.status {
            await check("device") { try await deviceDetail(request.deviceID) }
        } else {
            DoctorCheck(name: "device", status: .skipped("sim-use is not ready"))
        }
        let jev = await check("jev") { try jevDetail(request) }
        // An installed skill for another version fails the check; no installed skill passes.
        let skillWarnings = SkillVersionCheck(environment: environment).warnings()
        let skill = DoctorCheck(name: "skill", status: skillWarnings.isEmpty
            ? .passed("no installed copy is for another version than \(JevSimUseVersion.current)")
            : .failed(skillWarnings.joined(separator: "\n")))
        return DoctorReport(checks: [simUse, device, jev, skill])
    }

    private func check(_ name: String, _ body: () async throws -> String) async -> DoctorCheck {
        do {
            return try await DoctorCheck(name: name, status: .passed(body()))
        } catch {
            return DoctorCheck(name: name, status: .failed("\(error)"))
        }
    }
}

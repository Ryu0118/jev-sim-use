package extension SimUseBootstrap {
    /// The variable sim-use itself reads when `--device` is omitted.
    static let deviceVariable = "SIM_USE_DEVICE"

    /// `flag`, falling back to `$SIM_USE_DEVICE` like sim-use does; `nil` lets the only usable device be picked.
    static func deviceID(flag: String?, environment: [String: String]) -> String? {
        flag ?? environment[deviceVariable].flatMap { $0.isEmpty ? nil : $0 }
    }
}

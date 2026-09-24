import ArgumentParser
import Foundation
import SimJevUseKit

/// Options shared by `run` and `doctor`.
struct ConnectionOptions: ParsableArguments {
    @Option(
        name: [.short, .long],
        help: "sim-use device id. Default: $SIM_USE_DEVICE, else the only booted simulator or connected device.",
    )
    var device: String?

    @Option(help: "Jev base URL. Overrides $TYPESAFE_BASE_URL and `config set base-url`.")
    var baseURL: String?

    @Option(help: "Jev model. Overrides $TYPESAFE_MODEL and `config set model`. Default: jev-latest.")
    var model: String?

    /// `--device`, falling back to the variable sim-use itself honours.
    var resolvedDevice: String? {
        device ?? ProcessInfo.processInfo.environment["SIM_USE_DEVICE"].flatMap { $0.isEmpty ? nil : $0 }
    }

    func jevSettings() throws -> JevSettings {
        try JevSettings.resolve(baseURLFlag: baseURL, modelFlag: model, config: UserConfigStore().load())
    }
}

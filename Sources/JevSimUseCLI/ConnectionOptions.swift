import ArgumentParser
import JevSimUseKit

/// Options shared by `run` and `doctor`.
struct ConnectionOptions: ParsableArguments {
    @Option(
        name: [.short, .long],
        help: "sim-use device id. Default: $SIM_USE_DEVICE, else the only booted simulator or connected device.",
    )
    var device: String?

    @Option(help: "Jev base URL. Overrides $TYPESAFE_BASE_URL and `config set base-url`.")
    var baseURL: String?

    @Option(help: "Jev model. Overrides $TYPESAFE_MODEL and `config set model`. Default: jev-1.13.0.")
    var model: String?
}

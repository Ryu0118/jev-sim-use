import ArgumentParser

struct JevOptions: ParsableArguments {
    @Option(help: "Jev evaluation URL. Overrides $TYPESAFE_ENDPOINT. HTTPS, or HTTP on localhost only.")
    var endpoint: String?

    @Option(help: "Jev model. Overrides $TYPESAFE_MODEL. Default: jev-latest.")
    var model: String?
}

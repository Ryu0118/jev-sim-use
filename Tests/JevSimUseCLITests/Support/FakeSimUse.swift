import Foundation

/// A stand-in `sim-use` on a temporary `PATH`, so CLI tests exercise the real process wiring without a simulator.
struct FakeSimUse {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)

    /// Installs a script answering `--version`, `devices`, and `ui` like sim-use 0.14.0; returns the environment.
    func environment() throws -> [String: String] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let script = """
        #!/bin/sh
        case "$1" in
          --version) echo v0.14.0 ;;
          devices) echo '{"ok":true,"data":{"devices":[{"deviceId":"FAKE-DEVICE","kind":"simulator",\
        "name":"Fake iPhone","platform":"ios","state":"Booted"}]}}' ;;
          ui) echo '{"ok":true,"data":{"platform":"ios","outline":"App: Fake","entries":[]}}' ;;
          *) echo "unexpected: $*" >&2; exit 64 ;;
        esac
        """
        FileManager.default.createFile(
            atPath: directory.appending(path: "sim-use").path(percentEncoded: false),
            contents: Data(script.utf8),
            attributes: [.posixPermissions: 0o755],
        )
        return [
            "PATH": directory.path(percentEncoded: false),
            "XDG_CONFIG_HOME": directory.appending(path: "config").path(percentEncoded: false),
        ]
    }
}

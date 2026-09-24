import Foundation

/// A throwaway directory with executable stubs, for tests that search `PATH`.
struct TemporaryPath {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)

    /// Creates `name` as an executable file in the directory and returns the directory path.
    func withExecutable(_ name: String) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appending(path: name).path(percentEncoded: false)
        FileManager.default.createFile(atPath: path, contents: Data("#!/bin/sh\n".utf8), attributes: [.posixPermissions: 0o755])
        return directory.path(percentEncoded: false)
    }
}

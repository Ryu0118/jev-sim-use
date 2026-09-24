import Foundation

/// Progress goes to stderr so stdout carries only the final outcome.
enum Console {
    static func error(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}

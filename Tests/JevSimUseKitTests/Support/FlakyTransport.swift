import Foundation
import Jev
import Synchronization

/// Fails the first `failures` sends with a dropped connection, then answers with `body`.
final class FlakyTransport: JevTransport {
    private let remaining: Mutex<Int>
    private let body: String

    init(failures: Int, body: String) {
        remaining = Mutex(failures)
        self.body = body
    }

    func send(_: JevHTTPRequest) async throws -> JevHTTPResponse {
        let fail = remaining.withLock { remaining in
            defer { remaining -= 1 }
            return remaining > 0
        }
        if fail {
            throw URLError(.networkConnectionLost)
        }
        return JevHTTPResponse(status: 200, headers: [:], body: Data(body.utf8))
    }
}

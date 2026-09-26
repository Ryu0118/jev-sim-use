import Foundation
import Jev
@testable import JevSimUseKit
import Synchronization

/// Drops the first `droppedConnections` requests as a lost connection, then answers every request with `body`.
final class StubTransport: JevTransport {
    private let remaining: Mutex<Int>
    private let body: String

    init(body: String, droppedConnections: Int = 0) {
        remaining = Mutex(droppedConnections)
        self.body = body
    }

    func send(_: JevHTTPRequest) async throws -> JevHTTPResponse {
        let drop = remaining.withLock { remaining in
            defer { remaining -= 1 }
            return remaining > 0
        }
        if drop {
            throw URLError(.networkConnectionLost)
        }
        return JevHTTPResponse(status: 200, headers: [:], body: Data(body.utf8))
    }

    /// A planner that sends every request to this transport.
    func planner() -> JevStepPlanner {
        let client = JevClient(apiKey: "k", endpoint: URL(string: "http://localhost/jev")!, transport: self, retryPolicy: .none)
        return JevStepPlanner(client: client)
    }
}

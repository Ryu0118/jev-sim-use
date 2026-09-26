import Foundation
import Jev
@testable import JevSimUseKit

/// Returns one canned HTTP response to every request.
final class StubTransport: JevTransport {
    private let response: JevHTTPResponse

    init(status: Int = 200, body: String) {
        response = JevHTTPResponse(status: status, headers: [:], body: Data(body.utf8))
    }

    func send(_: JevHTTPRequest) async throws -> JevHTTPResponse {
        response
    }

    /// A planner that sends every request to this transport.
    func planner() -> JevStepPlanner {
        let client = JevClient(apiKey: "k", endpoint: URL(string: "http://localhost/jev")!, transport: self, retryPolicy: .none)
        return JevStepPlanner(client: client)
    }
}

import Foundation
import Jev
import Synchronization

/// Returns one canned HTTP response and keeps the request for inspection.
final class StubTransport: JevTransport {
    private let response: JevHTTPResponse
    private let requests = Mutex<[JevHTTPRequest]>([])

    var lastRequestBody: String? {
        requests.withLock { $0.last.flatMap { String(bytes: $0.body, encoding: .utf8) } }
    }

    init(status: Int = 200, body: String) {
        response = JevHTTPResponse(status: status, headers: [:], body: Data(body.utf8))
    }

    func send(_ request: JevHTTPRequest) async throws -> JevHTTPResponse {
        requests.withLock { $0.append(request) }
        return response
    }

    static func answer(choice: String, confidence: Double = 0.9, goal: Double = 0.1) -> String {
        """
        {"model":"jev-latest","answers":{"goal_reached":{"type":"noul","noul":\(goal)},\
        "next_action":{"type":"choice","choice":"\(choice)","probabilities":{"\(choice)":\(confidence)},\
        "confidence":\(confidence)}},"usage":{"input_tokens":1000,"output_tokens":10}}
        """
    }
}

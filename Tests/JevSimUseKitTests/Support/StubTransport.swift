import Foundation
import Jev
@testable import JevSimUseKit
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

    /// A response choosing `operation`, plus other choice answers in `extra` (question, choice, confidence).
    static func answer(
        operation: String,
        confidence: Double = 0.9,
        finishes: Double = 0.1,
        extra: [(question: String, choice: String, confidence: Double)] = [],
    ) -> String {
        let choices = ([("operation", operation, confidence)] + extra).map { question, choice, confidence in
            #""\#(question)":{"type":"choice","choice":"\#(choice)","probabilities":{"\#(choice)":\#(confidence)},"confidence":\#(confidence)}"#
        }
        return #"{"model":"jev-latest","answers":{"finishes":{"type":"noul","noul":\#(finishes)},"#
            + choices.joined(separator: ",") + #"},"usage":{"input_tokens":1000,"output_tokens":10}}"#
    }

    /// A planner that sends every request to this transport.
    func planner() -> JevStepPlanner {
        let client = JevClient(apiKey: "k", endpoint: URL(string: "http://localhost/jev")!, transport: self, retryPolicy: .none)
        return JevStepPlanner(client: client)
    }
}

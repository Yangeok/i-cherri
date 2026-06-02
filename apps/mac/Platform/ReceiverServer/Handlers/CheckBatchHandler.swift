import Foundation
import ICherriProtocol
import ICherriCore

// Handles POST /backup/check-batch
struct CheckBatchHandler: Sendable {
    private let processor: CheckBatchProcessor

    init(processor: CheckBatchProcessor) {
        self.processor = processor
    }

    func handle(_ request: HTTPRequest) async -> HTTPResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let body = try? decoder.decode(CheckBatchRequest.self, from: request.body) else {
            return .error(code: "invalid_body", message: "Failed to parse CheckBatchRequest")
        }

        do {
            let response = try await processor.process(request: body)
            return (try? HTTPResponse.json(response)) ?? .error(code: "encode_error", message: "Failed to encode response", status: 500)
        } catch {
            return .error(code: "processing_error", message: error.localizedDescription, status: 500)
        }
    }
}

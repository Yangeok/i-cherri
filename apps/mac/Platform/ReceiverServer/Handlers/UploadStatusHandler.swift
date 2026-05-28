import Foundation
import ICherriProtocol

// Handles GET /uploads/{uploadId}/status for resumable upload session resumption.
final class UploadStatusHandler {
    private let sessionManager: SessionManager
    private let encoder: JSONEncoder

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    func handle(_ request: HTTPRequest, uploadID: String) async -> HTTPResponse {
        do {
            guard let session = try await sessionManager.fetchSession(uploadID: uploadID) else {
                return .error(code: "session_not_found", message: "Upload session not found", status: 404)
            }

            if session.expiresAt < Date() {
                return .error(code: "session_expired", message: "Upload session has expired", status: 410)
            }

            let response = UploadStatusResponse(
                uploadID: session.uploadID,
                status: session.status,
                receivedBytes: session.receivedBytes,
                expiresAt: session.expiresAt
            )
            return (try? HTTPResponse.json(response)) ?? .error(code: "encode_error", message: "Encode failed", status: 500)
        } catch {
            return .error(code: "lookup_error", message: error.localizedDescription, status: 500)
        }
    }
}

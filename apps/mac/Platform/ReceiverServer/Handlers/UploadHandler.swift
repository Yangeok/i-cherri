import Foundation
import ICherriProtocol

// Handles POST /uploads/init and PUT /uploads/{id}/chunks/{index}
final class UploadHandler {
    private let sessionManager: SessionManager
    private let incomingDir: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(sessionManager: SessionManager, incomingDir: URL) {
        self.sessionManager = sessionManager
        self.incomingDir = incomingDir
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // POST /uploads/init
    func handleInit(_ request: HTTPRequest) async -> HTTPResponse {
        guard let body = try? decoder.decode(UploadInitRequest.self, from: request.body) else {
            return .error(code: "invalid_body", message: "Failed to parse UploadInitRequest")
        }

        do {
            let uploadID = UUID().uuidString
            let tempPath = incomingDir.appendingPathComponent(uploadID + ".tmp")
            let expiresAt = Date().addingTimeInterval(24 * 3600)

            // Serialize AssetMetadata to JSON string
            let metadataData = try JSONEncoder().encode(body.asset)
            let metadataJson = String(data: metadataData, encoding: .utf8) ?? ""

            try await sessionManager.createSession(
                uploadID: uploadID,
                deviceID: body.device.deviceID,
                assetLocalID: body.asset.assetLocalID,
                tempPath: tempPath.path,
                expectedByteSize: body.expectedByteSize,
                chunkSize: body.requestedChunkSize,
                expiresAt: expiresAt,
                metadataJson: metadataJson
            )

            FileManager.default.createFile(atPath: tempPath.path, contents: nil)

            let response = UploadInitResponse(
                uploadID: uploadID,
                accepted: true,
                chunkSize: body.requestedChunkSize,
                receivedBytes: 0,
                expiresAt: expiresAt
            )
            return (try? HTTPResponse.json(response, status: 200)) ?? .error(code: "encode_error", message: "Encode failed", status: 500)
        } catch {
            return .error(code: "session_error", message: error.localizedDescription, status: 500)
        }
    }

    // PUT /uploads/{uploadId}/chunks/{index}
    func handleChunk(_ request: HTTPRequest, uploadID: String, chunkIndex: Int) async -> HTTPResponse {
        do {
            guard let session = try await sessionManager.fetchSession(uploadID: uploadID) else {
                return .error(code: "session_not_found", message: "Upload session not found", status: 404)
            }

            let tempURL = URL(fileURLWithPath: session.tempPath)
            guard let fileHandle = FileHandle(forWritingAtPath: tempURL.path) else {
                return .error(code: "io_error", message: "Cannot open temp file", status: 500)
            }

            let offset = Int64(chunkIndex) * Int64(session.chunkSize)
            fileHandle.seek(toFileOffset: UInt64(offset))
            fileHandle.write(request.body)
            fileHandle.closeFile()

            let newReceived = min(offset + Int64(request.body.count), session.expectedByteSize)
            try await sessionManager.updateProgress(uploadID: uploadID, receivedBytes: newReceived, status: "receiving")

            let response = ChunkUploadResponse(uploadID: uploadID, index: chunkIndex, receivedBytes: newReceived)
            return (try? HTTPResponse.json(response)) ?? .error(code: "encode_error", message: "Encode failed", status: 500)
        } catch {
            return .error(code: "chunk_error", message: error.localizedDescription, status: 500)
        }
    }
}

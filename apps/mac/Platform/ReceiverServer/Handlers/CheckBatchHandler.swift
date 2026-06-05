import Foundation
import ICherriProtocol
import ICherriCore

// Handles POST /backup/check-batch
struct CheckBatchHandler: Sendable {
    private let processor: CheckBatchProcessor
    private let progressStore: BackupRunProgressStore
    private let databaseManager: DatabaseManager

    init(processor: CheckBatchProcessor, progressStore: BackupRunProgressStore, databaseManager: DatabaseManager) {
        self.processor = processor
        self.progressStore = progressStore
        self.databaseManager = databaseManager
    }

    func handle(_ request: HTTPRequest) async -> HTTPResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let body = try? decoder.decode(CheckBatchRequest.self, from: request.body) else {
            return .error(code: "invalid_body", message: "Failed to parse CheckBatchRequest")
        }

        do {
            if let backupRunID = body.backupRunID, !backupRunID.isEmpty {
                try await databaseManager.replaceBackupRunSnapshot(
                    runID: backupRunID,
                    device: body.device,
                    librarySnapshot: body.librarySnapshot,
                    candidates: body.candidates
                )
            }
            let response = try await processor.process(request: body)
            await progressStore.recordCheckBatch(request: body, response: response)
            return (try? HTTPResponse.json(response)) ?? .error(code: "encode_error", message: "Failed to encode response", status: 500)
        } catch {
            return .error(code: "processing_error", message: error.localizedDescription, status: 500)
        }
    }
}

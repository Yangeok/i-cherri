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
            var response = try await processor.process(request: body)

            // Mac DB 기준 완료 파일 수를 조회해 iOS가 로컬 추정값 대신 이 값을 SSOT로 쓸 수 있도록 주입
            let completedCount = (try? await databaseManager.fetchCompletedAssetCount(deviceID: body.device.deviceID)) ?? 0
            response = CheckBatchResponse(
                requiredUploads: response.requiredUploads,
                alreadyBackedUp: response.alreadyBackedUp,
                duplicates: response.duplicates,
                unsupported: response.unsupported,
                completedAssetCount: completedCount
            )

            await progressStore.recordCheckBatch(request: body, response: response)
            return (try? HTTPResponse.json(response)) ?? .error(code: "encode_error", message: "Failed to encode response", status: 500)
        } catch {
            return .error(code: "processing_error", message: error.localizedDescription, status: 500)
        }
    }
}

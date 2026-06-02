import Foundation

// Manages upload session state in the database for resumable chunk uploads.
actor SessionManager {
    private let dbManager: DatabaseManager

    init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    struct SessionInfo: Sendable {
        let uploadID: String
        let deviceID: String
        let assetLocalID: String
        let tempPath: String
        let expectedByteSize: Int64
        let receivedBytes: Int64
        let chunkSize: Int
        let status: String
        let expiresAt: Date
        let metadataJson: String
    }

    func createSession(
        uploadID: String,
        deviceID: String,
        assetLocalID: String,
        tempPath: String,
        expectedByteSize: Int64,
        chunkSize: Int,
        expiresAt: Date,
        metadataJson: String
    ) async throws {
        let now = Date()
        let record = UploadSessionRecord(
            uploadId: uploadID,
            deviceId: deviceID,
            assetLocalId: assetLocalID,
            tempPath: tempPath,
            expectedByteSize: expectedByteSize,
            receivedBytes: 0,
            chunkSize: chunkSize,
            status: "initialized",
            createdAt: now,
            updatedAt: now,
            expiresAt: expiresAt,
            metadataJson: metadataJson,
            lastError: nil
        )
        try await dbManager.insertUploadSession(record)
    }

    func fetchSession(uploadID: String) async throws -> SessionInfo? {
        guard let record = try await dbManager.fetchUploadSession(uploadId: uploadID) else { return nil }
        return SessionInfo(
            uploadID: record.uploadId,
            deviceID: record.deviceId,
            assetLocalID: record.assetLocalId,
            tempPath: record.tempPath,
            expectedByteSize: record.expectedByteSize,
            receivedBytes: record.receivedBytes,
            chunkSize: record.chunkSize,
            status: record.status,
            expiresAt: record.expiresAt,
            metadataJson: record.metadataJson
        )
    }

    func updateProgress(uploadID: String, receivedBytes: Int64, status: String) async throws {
        try await dbManager.updateUploadProgress(uploadId: uploadID, receivedBytes: receivedBytes, status: status)
    }

    func completeSession(uploadID: String) async throws {
        try await dbManager.deleteUploadSession(uploadId: uploadID)
    }

    func failSession(uploadID: String, errorCode: String, errorMessage: String) async throws {
        guard let session = try await dbManager.fetchUploadSession(uploadId: uploadID) else { return }

        let record = UploadFailureLogRecord(
            id: nil,
            uploadId: session.uploadId,
            deviceId: session.deviceId,
            assetLocalId: session.assetLocalId,
            status: "failed",
            errorCode: errorCode,
            errorMessage: errorMessage,
            receivedBytes: session.receivedBytes,
            expectedByteSize: session.expectedByteSize,
            createdAt: Date(),
            metadataJson: session.metadataJson
        )
        try await dbManager.insertUploadFailureLog(record)
        try await dbManager.deleteUploadSession(uploadId: uploadID)
    }

    func pauseSession(uploadID: String) async throws {
        guard let session = try await fetchSession(uploadID: uploadID) else { return }
        try await dbManager.updateUploadProgress(uploadId: uploadID, receivedBytes: session.receivedBytes, status: "paused")
    }

    func fetchExpiredSessions() async throws -> [SessionInfo] {
        let records = try await dbManager.fetchExpiredSessions()
        return records.map { r in
            SessionInfo(
                uploadID: r.uploadId,
                deviceID: r.deviceId,
                assetLocalID: r.assetLocalId,
                tempPath: r.tempPath,
                expectedByteSize: r.expectedByteSize,
                receivedBytes: r.receivedBytes,
                chunkSize: r.chunkSize,
                status: r.status,
                expiresAt: r.expiresAt,
                metadataJson: r.metadataJson
            )
        }
    }
}

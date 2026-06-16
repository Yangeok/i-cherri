import Foundation
import ICherriProtocol

// Orchestrates the scan → check-batch → upload loop against a receiver endpoint.
public actor BackupClient {
    private let receiverBaseURL: URL
    private let device: DeviceInfo
    private let trustToken: String?
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(receiverBaseURL: URL, device: DeviceInfo, trustToken: String? = nil) {
        self.receiverBaseURL = receiverBaseURL
        self.device = device
        self.trustToken = trustToken
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // Runs check-batch and returns which assets need uploading.
    public func checkBatch(
        backupRunID: String? = nil,
        candidates: [AssetMetadata],
        totalAssetCount: Int,
        totalAssetBytes: Int64
    ) async throws -> CheckBatchResponse {
        let request = CheckBatchRequest(
            backupRunID: backupRunID,
            device: device,
            candidates: candidates,
            librarySnapshot: CheckBatchLibrarySnapshot(
                totalAssetCount: totalAssetCount,
                totalAssetBytes: totalAssetBytes
            )
        )
        return try await post(path: "/backup/check-batch", body: request)
    }

    public func finalizeBackupRun(backupRunID: String) async throws -> FinalizeBackupRunResponse {
        let request = FinalizeBackupRunRequest(backupRunID: backupRunID, device: device)
        return try await post(path: "/backup/finalize-run", body: request)
    }

    // Fetches receiver info (no auth required).
    public func fetchReceiverInfo() async throws -> ReceiverInfo {
        let url = receiverBaseURL.appendingPathComponent("/receiver/info")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(ReceiverInfo.self, from: data)
    }

    // Initiates an upload session.
    public func initUpload(
        backupRunContext: AutoBackupRunContext? = nil,
        asset: AssetMetadata,
        filename: String
    ) async throws -> UploadInitResponse {
        let request = UploadInitRequest(
            backupRunContext: backupRunContext,
            device: device,
            asset: asset,
            filename: filename
        )
        return try await post(path: "/uploads/init", body: request)
    }

    // Queries upload session status for resumption.
    public func uploadStatus(uploadID: String) async throws -> UploadStatusResponse {
        let url = receiverBaseURL.appendingPathComponent("/uploads/\(uploadID)/status")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        attachAuthHeaders(&req)
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(UploadStatusResponse.self, from: data)
    }

    // Commits an upload session.
    public func commitUpload(
        backupRunContext: AutoBackupRunContext? = nil,
        uploadID: String,
        assetLocalID: String,
        finalByteSize: Int64,
        finalContentHash: String
    ) async throws -> CommitUploadResponse {
        let request = CommitUploadRequest(
            backupRunContext: backupRunContext,
            uploadID: uploadID,
            assetLocalID: assetLocalID,
            finalByteSize: finalByteSize,
            finalContentHash: finalContentHash
        )
        return try await post(path: "/uploads/\(uploadID)/commit", body: request)
    }

    // MARK: - Helpers

    private func post<Req: Encodable, Res: Decodable>(path: String, body: Req) async throws -> Res {
        let url = receiverBaseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        attachAuthHeaders(&req)
        req.httpBody = try encoder.encode(body)
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw BackupClientError.httpError(http.statusCode, data)
        }
        return try decoder.decode(Res.self, from: data)
    }

    private func attachAuthHeaders(_ request: inout URLRequest) {
        request.setValue(device.deviceID, forHTTPHeaderField: "X-iCherri-Device-ID")
        if let trustToken, !trustToken.isEmpty {
            request.setValue(trustToken, forHTTPHeaderField: "X-iCherri-Token")
        }
    }
}

public enum BackupClientError: Error {
    case httpError(Int, Data)
    case invalidResponse
}

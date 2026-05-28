import Foundation
import CryptoKit
import ICherriProtocol

// Manages the full lifecycle of a resumable upload: init → chunk send → (resume on abort) → commit.
public actor ResumableUploadManager {
    private let backupClient: BackupClient
    private let chunkSender: ChunkUploadSender
    private let scanner: PhotoLibraryScanner

    public init(backupClient: BackupClient, chunkSender: ChunkUploadSender, scanner: PhotoLibraryScanner) {
        self.backupClient = backupClient
        self.chunkSender = chunkSender
        self.scanner = scanner
    }

    public struct UploadResult: Sendable {
        public let assetLocalID: String
        public let backupID: String
        public let displayPath: String
    }

    // Performs a full upload with automatic resumption if interrupted.
    public func upload(
        assetLocalID: String,
        metadata: AssetMetadata
    ) async throws -> UploadResult {
        // Init or resume existing session
        let (uploadID, startOffset, chunkSize) = try await initOrResumeSession(metadata: metadata)

        // Fetch data and send
        let data = try await scanner.fetchData(for: assetLocalID)
        let contentHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        try await chunkSender.send(
            data: data,
            uploadID: uploadID,
            chunkSize: chunkSize,
            startingOffset: startOffset
        )

        // Commit
        let commitResponse = try await backupClient.commitUpload(
            uploadID: uploadID,
            assetLocalID: assetLocalID,
            finalByteSize: metadata.byteSize,
            finalContentHash: contentHash
        )

        guard let backupID = commitResponse.backupID, let displayPath = commitResponse.displayPath else {
            throw ResumableUploadError.commitFailed(commitResponse.status)
        }

        return UploadResult(assetLocalID: assetLocalID, backupID: backupID, displayPath: displayPath)
    }

    // MARK: - Private

    private func initOrResumeSession(metadata: AssetMetadata) async throws -> (uploadID: String, startOffset: Int64, chunkSize: Int) {
        // Try to find an existing paused session
        let initResponse = try await backupClient.initUpload(asset: metadata, filename: metadata.originalFilename)

        // If already received some bytes (server reused session), resume from there
        if initResponse.receivedBytes > 0 {
            return (initResponse.uploadID, initResponse.receivedBytes, initResponse.chunkSize)
        }

        // Check if server has partial data for a previous session with same asset
        do {
            let status = try await backupClient.uploadStatus(uploadID: initResponse.uploadID)
            if status.status == "receiving" || status.status == "paused", status.receivedBytes > 0 {
                return (initResponse.uploadID, status.receivedBytes, initResponse.chunkSize)
            }
        } catch {
            // No prior session found — start fresh
        }

        return (initResponse.uploadID, 0, initResponse.chunkSize)
    }
}

public enum ResumableUploadError: Error {
    case commitFailed(String)
    case sessionExpired
}
